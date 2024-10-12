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

	scrollSpeed:Dynamic, // Like a Map<String, Float>
	notes:Dynamic, // Like a Map<String, Array<FNFVSliceNote>
	events:Array<FNFVSliceEvent>
}

typedef FNFVSliceNote =
{
	t:Float,
	d:Int,
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
	altInstrumentals:Dynamic, // Like a Map<String, Float>
	vocals:Dynamic
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

enum abstract FNFVSliceCamFocus(Int) from Int to Int
{
	var BF = 0;
	var DAD = 1;
	var GF = 2;
}

class FNFVSlice extends BasicFormat<FNFVSliceFormat, FNFVSliceMeta>
{
	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_VSLICE,
			name: "FNF (V-Slice)",
			description: "",
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
	public static inline var VSLICE_META_VERSION:String = "2.2.2";
	public static inline var VSLICE_MANIFEST_VERSION:String = "1.0.0";

	public function new(?data:FNFVSliceFormat, ?meta:FNFVSliceMeta)
	{
		super({timeFormat: MILLISECONDS, supportsDiffs: true, supportsEvents: true});
		this.data = data;
		this.meta = meta;
	}

	// Could be useful converting erect mixes
	public var defaultSongVariations:Array<String> = [];

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFVSlice
	{
		var chartResolve = resolveDiffsNotes(chart, diff).notes;
		var meta = chart.meta;

		var notes:Dynamic = {};
		var scrollSpeed:Dynamic = {};

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
		final lanesLength:Int = (meta.extraData.get(LANES_LENGTH) ?? 8) <= 7 ? 4 : 8;

		for (chartDiff => chart in chartResolve)
		{
			var timeChangeIndex = 1;
			var stepCrochet:Float = Timing.stepCrochet(timeChanges[0].bpm, 4);
			var chartNotes:Array<FNFVSliceNote> = [];

			for (note in chart)
			{
				var time = note.time;
				var length = note.length;

				// Find the last bpm change
				while (timeChangeIndex < timeChanges.length && timeChanges[timeChangeIndex].t <= time)
				{
					stepCrochet = Timing.stepCrochet(timeChanges[timeChangeIndex++].bpm, 4);
				}

				// Offset sustain length, vslice starts a step crochet later
				chartNotes.push({
					t: time,
					d: (note.lane + 4 + lanesLength) % 8,
					l: length > 0 ? length - (stepCrochet * 0.5) : 0,
					k: note.type
				});
			}

			var speed:Float = meta.scrollSpeeds.get(chartDiff) ?? 1.0;

			Reflect.setField(notes, chartDiff, chartNotes);
			Reflect.setField(scrollSpeed, chartDiff, speed);
		}

		var events:Array<FNFVSliceEvent> = [];
		for (event in chart.data.events)
		{
			var isFocus = isCamFocusEvent(event) && event.name != VSLICE_FOCUS_EVENT;
			events.push(isFocus ? {
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

		var difficulties:Array<String> = [];
		for (i in chart.data.diffs.keys())
			difficulties.push(i);

		var extra = meta.extraData;

		var p1:String = extra.get(PLAYER_1) ?? "bf";
		var p2:String = extra.get(PLAYER_2) ?? "dad";

		var vocalsMap:Null<Map<String, Float>> = extra.get(VOCALS_OFFSET);
		var vocalsOffset:Dynamic = {};
		if (vocalsMap != null)
		{
			for (vocal => offset in vocalsMap)
			{
				switch (vocal)
				{
					case PLAYER_1:
						Reflect.setField(vocalsOffset, p1, offset);
					case PLAYER_2:
						Reflect.setField(vocalsOffset, p2, offset);
					case _:
						Reflect.setField(vocalsOffset, vocal, offset);
				}
			}
		}

		this.meta = {
			timeFormat: "ms",
			artist: extra.get(SONG_ARTIST) ?? "Unknown",
			charter: extra.get(SONG_CHARTER) ?? "Unknown",
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
				altInstrumentals: {} // TODO: whatever this is
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
		var chartNotes:Array<FNFVSliceNote> = Reflect.field(data.notes, diff);
		if (chartNotes == null)
		{
			throw "Couldn't find FNF (V-Slice) notes for difficulty " + (diff ?? "null");
			return null;
		}

		var notes:Array<BasicNote> = [];

		var timeChanges = meta.timeChanges;
		var stepCrochet = Timing.stepCrochet(timeChanges[0].bpm, 4);
		var i:Int = 1;

		// Make sure all notes are in order
		chartNotes.sort((a, b) -> Util.sortValues(a.t, b.t));

		for (note in chartNotes)
		{
			var time = note.t;
			var length = note.l ?? 0.0;
			var type = note.k ?? "";

			// Find the current bpm change
			while (i < timeChanges.length && timeChanges[i].t <= time)
			{
				stepCrochet = Timing.stepCrochet(timeChanges[i++].bpm, 4);
			}

			notes.push({
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

		var vocalsOffset:Map<String, Float> = [];
		for (vocal in Reflect.fields(meta.offsets?.vocals ?? {}))
		{
			var offset:Float = Reflect.field(meta.offsets.vocals, vocal);
			vocalsOffset.set(vocal, offset);
		}

		var scrollSpeeds:Map<String, Float> = [];
		for (diff in Reflect.fields(data.scrollSpeed))
		{
			var speed:Float = Reflect.field(data.scrollSpeed, diff);
			scrollSpeeds.set(diff, speed);
		}

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

	override function stringify(?formatting:String = "\t")
	{
		return {
			data: Json.stringify(data, formatting),
			meta: Json.stringify(meta, formatting)
		}
	}

	public override function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):FNFVSlice
	{
		return fromJson(Util.getText(path), Util.getText(meta), diff);
	}

	public function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFVSlice
	{
		// TODO: add support for manifest json
		this.data = Json.parse(data);
		this.meta = Json.parse(meta);

		this.diffs = diff ?? Reflect.fields(this.data.notes);
		return this;
	}
}
