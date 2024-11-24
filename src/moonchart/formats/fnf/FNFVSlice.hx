package moonchart.formats.fnf;

import moonchart.backend.FormatData;
import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy.FNFLegacyEvent;
import moonchart.formats.fnf.legacy.FNFLegacy.FNFLegacyMetaValues;
import haxe.Json;

using StringTools;

typedef FNFVSliceFormat =
{
	version:String,
	generatedBy:String,

	scrollSpeed:JsonMap<Float>,
	notes:JsonMap<Array<FNFVSliceNote>>,
	events:Array<FNFVSliceEvent>
}

typedef FNFVSliceNote =
{
	t:Float,
	d:Int8,
	l:Float,
	k:String
}

typedef FNFVSliceEvent =
{
	t:Float,
	e:String,
	v:Dynamic
}

typedef FNFVSliceMeta =
{
	timeFormat:String,
	artist:String,
	charter:String,
	generatedBy:String,
	version:String,

	playData:FNFVSlicePlayData,
	songName:String,
	offsets:FNFVSliceOffsets,
	timeChanges:Array<FNFVSliceTimeChange>
}

typedef FNFVSliceTimeChange =
{
	// TODO: look what the other variables do
	t:Float,
	bpm:Float,
	n:Int,
	d:Int
}

typedef FNFVSliceOffsets =
{
	instrumental:Float,
	vocals:JsonMap<Float>,
	altInstrumentals:JsonMap<Float>,
	altVocals:JsonMap<JsonMap<Float>>
}

typedef FNFVSliceManifest =
{
	version:String,
	songId:String
}

typedef FNFVSlicePlayData =
{
	characters:
	{
		player:String, girlfriend:String, opponent:String
	},
	difficulties:Array<String>,
	songVariations:Array<String>,
	noteStyle:String,
	stage:String
}

enum abstract FNFVSliceMetaValues(String) from String to String
{
	var SONG_VARIATIONS = "FNF_SONG_VARIATIONS";
}

enum abstract FNFVSliceCamFocus(Int8) from Int8 to Int8
{
	var BF = 0;
	var DAD = 1;
	var GF = 2;
}

class FNFVSlice extends BasicJsonFormat<FNFVSliceFormat, FNFVSliceMeta>
{
	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_VSLICE,
			name: "FNF (V-Slice)",
			description: "The new and handsome FNF format.",
			extension: "json",
			formatFile: formatFile,
			hasMetaFile: TRUE,
			metaFileExtension: "json",
			specialValues: ['"scrollSpeed":', '"version":'],
			findMeta: (files) ->
			{
				for (file in files)
				{
					if (Util.getText(file).contains('"playData":'))
						return file;
				}
				return files[0];
			},
			handler: FNFVSlice
		}
	}

	public static function formatFile(title:String, diff:String):Array<String>
	{
		title = title.trim().toLowerCase();
		return ['$title-chart', '$title-metadata'];
	}

	public static inline var VSLICE_FOCUS_EVENT:String = "FocusCamera";
	public static inline var VSLICE_DEFAULT_NOTE:String = "normal";

	public static inline var VSLICE_CHART_VERSION:String = "2.0.0";
	public static inline var VSLICE_META_VERSION:String = "2.2.4";
	public static inline var VSLICE_MANIFEST_VERSION:String = "1.0.0";

	public function new(?data:FNFVSliceFormat, ?meta:FNFVSliceMeta)
	{
		super({timeFormat: MILLISECONDS, supportsDiffs: true, supportsEvents: true});
		this.data = data;
		this.meta = meta;
		beautify = true;
	}

	// Could be useful converting erect mixes
	public var defaultSongVariations:Array<String> = [];

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFVSlice
	{
		var chartResolve = resolveDiffsNotes(chart, diff).notes;
		var meta = chart.meta;

		var notes:JsonMap<Array<FNFVSliceNote>> = {};
		var scrollSpeed:JsonMap<Float> = {};

		var basicBpmChanges = meta.bpmChanges.copy();
		var timeChanges:Array<FNFVSliceTimeChange> = [];

		for (change in basicBpmChanges)
		{
			timeChanges.push({
				t: change.time,
				bpm: change.bpm,
				n: Std.int(change.stepsPerBeat),
				d: Std.int(change.beatsPerMeasure)
			});
		}

		timeChanges.sort((a, b) -> return Util.sortValues(a.t, b.t));
		final lanesLength:Int8 = (meta.extraData.get(LANES_LENGTH) ?? 8) <= 7 ? 4 : 8;

		for (chartDiff => chart in chartResolve)
		{
			var timeChangeIndex = 1;
			var stepCrochet:Float = Timing.stepCrochet(timeChanges[0].bpm, 4);
			var chartNotes:Array<FNFVSliceNote> = Util.makeArray(chart.length);

			for (i in 0...chart.length)
			{
				var note = chart[i];
				var time = note.time;
				var length = note.length;

				// Find the last bpm change
				while (timeChangeIndex < timeChanges.length && timeChanges[timeChangeIndex].t <= time)
				{
					stepCrochet = Timing.stepCrochet(timeChanges[timeChangeIndex++].bpm, 4);
				}

				// Offset sustain length, vslice starts a step crochet later
				Util.setArray(chartNotes, i, {
					t: time,
					d: (note.lane + 4 + lanesLength) % 8,
					l: length > 0 ? length - (stepCrochet * 0.5) : 0,
					k: note.type
				});
			}

			var speed:Float = meta.scrollSpeeds.get(chartDiff) ?? 1.0;
			notes.set(chartDiff, chartNotes);
			scrollSpeed.set(chartDiff, speed);
		}

		var chartEvents = chart.data.events;
		var events:Array<FNFVSliceEvent> = Util.makeArray(chartEvents.length);

		for (i in 0...chartEvents.length)
		{
			var event = chartEvents[i];
			var isFocus:Bool = ((event.name != VSLICE_FOCUS_EVENT) && isCamFocusEvent(event));
			Util.setArray(events, i, isFocus ? {
				t: event.time,
				e: VSLICE_FOCUS_EVENT,
				v: {
					char: resolveCamFocus(event),
					ease: "CLASSIC"
				}
			} : {
				t: event.time,
				e: event.name,
				v: event.data
				});
		}

		this.data = {
			scrollSpeed: scrollSpeed,
			notes: notes,
			events: events,
			version: VSLICE_CHART_VERSION,
			generatedBy: Util.version
		}

		var difficulties:Array<String> = Util.mapKeyArray(chart.data.diffs);
		var extra = meta.extraData;

		var p1:String = extra.get(PLAYER_1) ?? "bf";
		var p2:String = extra.get(PLAYER_2) ?? "dad";

		var vocalsMap:Null<Map<String, Float>> = extra.get(VOCALS_OFFSET);
		var vocalsOffset:JsonMap<Float> = {};
		if (vocalsMap != null)
		{
			for (vocal => offset in vocalsMap)
			{
				switch (vocal)
				{
					case PLAYER_1:
						vocalsOffset.set(p1, offset);
					case PLAYER_2:
						vocalsOffset.set(p2, offset);
					default:
						vocalsOffset.set(vocal, offset);
				}
			}
		}

		this.meta = {
			timeFormat: "ms",
			artist: extra.get(SONG_ARTIST) ?? Settings.DEFAULT_ARTIST,
			charter: extra.get(SONG_CHARTER) ?? Settings.DEFAULT_CHARTER,
			playData: {
				stage: extra.get(STAGE) ?? "mainStage",
				difficulties: difficulties,
				characters: {
					player: p1,
					opponent: p2,
					girlfriend: extra.get(PLAYER_3) ?? "gf"
				},
				songVariations: extra.get(SONG_VARIATIONS) ?? defaultSongVariations,
				noteStyle: "funkin"
			},
			songName: meta.title,
			offsets: {
				vocals: vocalsOffset,
				instrumental: meta.offset,
				// TODO: whatever this is
				altInstrumentals: {},
				altVocals: {}
			},
			timeChanges: timeChanges,
			generatedBy: Util.version,
			version: VSLICE_META_VERSION
		}

		return this;
	}

	/**
	 * This is the main place where you want to store ways to resolve FNF cam movement events
	 * The resolve method should always return an integer of the target character index
	 * Normally it goes (0: bf, 1: dad, 2: gf)
	 */
	public static final camFocusResolve:Map<String, BasicEvent->FNFVSliceCamFocus> = [
		MUST_HIT_SECTION => (e) -> e.data.mustHitSection ? BF : DAD,
		FNFVSlice.VSLICE_FOCUS_EVENT => (e) -> Std.parseInt(Std.string(e.data.char)),
		FNFCodename.CODENAME_CAM_MOVEMENT => (e) ->
		{
			return switch (e.data.array[0])
			{
				case 0: DAD;
				case 1: BF;
				default: GF;
			}
		}
	];

	public static inline function filterEvents(events:Array<BasicEvent>)
	{
		return events.filter((e) -> return !isCamFocusEvent(e));
	}

	public static inline function isCamFocusEvent(event:BasicEvent):Bool
	{
		return camFocusResolve.exists(event.name);
	}

	public static inline function resolveCamFocus(event:BasicEvent):FNFVSliceCamFocus
	{
		return camFocusResolve.get(event.name)(event);
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var chartNotes:Array<FNFVSliceNote> = data.notes.get(diff);
		if (chartNotes == null)
		{
			throw "Couldn't find FNF (V-Slice) notes for difficulty " + (diff ?? "null");
			return null;
		}

		var timeChanges = meta.timeChanges;
		var stepCrochet = Timing.stepCrochet(timeChanges[0].bpm, 4);
		var i:Int = 1;

		// Make sure all notes are in order
		chartNotes.sort((a, b) -> Util.sortValues(a.t, b.t));
		var notes:Array<BasicNote> = Util.makeArray(chartNotes.length);

		for (n in 0...chartNotes.length)
		{
			var note = chartNotes[n];
			var time = note.t;
			var length = note.l ?? 0.0;
			var type = note.k ?? "";

			// Find the current bpm change
			while (i < timeChanges.length)
			{
				if (timeChanges[i].t > time)
					break;

				stepCrochet = Timing.stepCrochet(timeChanges[i++].bpm, 4);
			}

			Util.setArray(notes, n, {
				time: time,
				lane: (note.d + 4) % 8,
				length: length > 0 ? length + (stepCrochet * 0.5) : 0,
				type: resolveNoteType(type)
			});
		}

		Timing.sortNotes(notes);

		return notes;
	}

	function resolveNoteType(type:String):BasicNoteType
	{
		return switch (type)
		{
			case VSLICE_DEFAULT_NOTE: DEFAULT;
			case _: type;
		}
	}

	override function getEvents():Array<BasicEvent>
	{
		var events:Array<BasicEvent> = [];

		for (event in data.events)
		{
			events.push({
				time: event.t,
				name: event.e,
				data: event.v
			});
		}

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		for (change in meta.timeChanges)
		{
			bpmChanges.push({
				time: Math.max(change.t, 0), // Just making sure they all start at 0 lol
				bpm: change.bpm,
				beatsPerMeasure: 4,
				stepsPerBeat: 4
			});
		}

		var chars = meta.playData.characters;
		var vocalsOffset:Map<String, Float> = (meta.offsets?.vocals != null) ? meta.offsets.vocals.resolve() : [];
		var scrollSpeeds:Map<String, Float> = data.scrollSpeed.resolve();

		return {
			title: meta.songName,
			bpmChanges: bpmChanges,
			scrollSpeeds: scrollSpeeds,
			offset: meta.offsets?.instrumental ?? 0.0,
			extraData: [
				PLAYER_1 => chars.player,
				PLAYER_2 => chars.opponent,
				PLAYER_3 => chars.girlfriend,
				STAGE => meta.playData.stage,
				VOCALS_OFFSET => vocalsOffset,
				NEEDS_VOICES => true,
				SONG_ARTIST => meta.artist,
				SONG_CHARTER => meta.charter,
				SONG_VARIATIONS => meta.playData.songVariations ?? [],
				LANES_LENGTH => 8
			]
		}
	}

	public override function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):FNFVSlice
	{
		return fromJson(Util.getText(path), Util.getText(meta), diff);
	}

	public override function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFVSlice
	{
		super.fromJson(data, meta, diff);
		this.diffs = diff ?? this.data.notes.keys();
		return this;
	}
}
