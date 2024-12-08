package moonchart.formats.fnf;

import moonchart.backend.FormatData;
import moonchart.backend.Timing;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.FNFGlobal.FNFNoteTypeResolver;
import moonchart.formats.fnf.legacy.FNFLegacy.FNFLegacyMetaValues;

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
	album:String,
	previewStart:Int,
	previewEnd:Int,
	ratings:JsonMap<Int>,
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
	var SONG_RATINGS = "FNF_SONG_RATINGS";
	var SONG_PREVIEW_START = "FNF_SONG_PREVIEW_START";
	var SONG_PREVIEW_END = "FNF_SONG_PREVIEW_END";
}

enum abstract FNFVSliceNoteType(String) from String to String
{
	var VSLICE_DEFAULT = "normal";
	var VSLICE_MOM = "mom";
}

class FNFVSlice extends BasicJsonFormat<FNFVSliceFormat, FNFVSliceMeta>
{
	// FNF V-Slice constants
	public static inline var VSLICE_PREVIEW_END:Int = 15000;
	public static inline var VSLICE_DEFAULT_NOTE_SKIN:String = "funkin";
	public static inline var VSLICE_FOCUS_EVENT:String = "FocusCamera";

	public static inline var VSLICE_CHART_VERSION:String = "2.0.0";
	public static inline var VSLICE_META_VERSION:String = "2.2.4";
	public static inline var VSLICE_MANIFEST_VERSION:String = "1.0.0";

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

	public var noteTypeResolver(default, null):FNFNoteTypeResolver;

	public function new(?data:FNFVSliceFormat, ?meta:FNFVSliceMeta)
	{
		super({timeFormat: MILLISECONDS, supportsDiffs: true, supportsEvents: true});
		this.data = data;
		this.meta = meta;
		beautify = true;

		// Register FNF V-Slice note types
		noteTypeResolver = FNFGlobal.createNoteTypeResolver();
		noteTypeResolver.register(VSLICE_DEFAULT, DEFAULT);
		noteTypeResolver.register(VSLICE_MOM, ALT_ANIM);
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
				var note = Util.getArray(chart, i);
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
					k: noteTypeResolver.resolveFromBasic(note.type)
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
			var event = Util.getArray(chartEvents, i);
			var isFocus:Bool = ((event.name != VSLICE_FOCUS_EVENT) && FNFGlobal.isCamFocus(event));
			Util.setArray(events, i, isFocus ? {
				t: event.time,
				e: VSLICE_FOCUS_EVENT,
				v: {
					char: FNFGlobal.resolveCamFocus(event),
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

		var ratingsMap:Null<Map<String, Int>> = extra.get(SONG_RATINGS);
		var ratings:JsonMap<Int> = {};

		this.meta = {
			timeFormat: "ms",
			artist: extra.get(SONG_ARTIST) ?? Settings.DEFAULT_ARTIST,
			charter: extra.get(SONG_CHARTER) ?? Settings.DEFAULT_CHARTER,
			playData: {
				album: extra.get(SONG_ALBUM) ?? Settings.DEFAULT_ALBUM,
				previewStart: extra.get(SONG_PREVIEW_START) ?? 0,
				previewEnd: extra.get(SONG_PREVIEW_END) ?? 15000,
				ratings: ratings.fromMap(ratingsMap),
				stage: extra.get(STAGE) ?? "mainStage",
				difficulties: difficulties,
				characters: {
					player: p1,
					opponent: p2,
					girlfriend: extra.get(PLAYER_3) ?? "gf"
				},
				songVariations: extra.get(SONG_VARIATIONS) ?? defaultSongVariations,
				noteStyle: extra.get(SONG_NOTE_SKIN) ?? VSLICE_DEFAULT_NOTE_SKIN
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
			var kind = note.k ?? "";

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
				type: resolveNoteType(kind)
			});
		}

		Timing.sortNotes(notes);

		return notes;
	}

	function resolveNoteType(type:String):BasicNoteType
	{
		return noteTypeResolver.resolveToBasic(type);
	}

	override function getEvents():Array<BasicEvent>
	{
		var vsliceEvents = data.events;
		var events:Array<BasicEvent> = Util.makeArray(vsliceEvents.length);

		for (i in 0...vsliceEvents.length)
		{
			final event = Util.getArray(vsliceEvents, i);
			Util.setArray(events, i, {
				time: event.t,
				name: event.e,
				data: event.v
			});
		}

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var timeChanges = meta.timeChanges;
		var bpmChanges:Array<BasicBPMChange> = Util.makeArray(timeChanges.length);

		for (i in 0...timeChanges.length)
		{
			final change = Util.getArray(timeChanges, i);
			Util.setArray(bpmChanges, i, {
				time: Math.max(change.t, 0), // Just making sure they all start at 0 lol
				bpm: change.bpm,
				beatsPerMeasure: 4,
				stepsPerBeat: 4
			});
		}

		var chars = meta.playData.characters;
		var vocalsOffset:Map<String, Float> = (meta.offsets?.vocals != null) ? meta.offsets.vocals.resolve() : [];
		var songRatings:Map<String, Int> = (meta.playData?.ratings != null) ? meta.playData.ratings.resolve() : [];
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
				SONG_RATINGS => songRatings,
				SONG_ALBUM => meta.playData.album ?? Settings.DEFAULT_ALBUM,
				SONG_PREVIEW_START => meta.playData.previewStart ?? 0,
				SONG_PREVIEW_END => meta.playData.previewEnd ?? 15000,
				// SONG_NOTE_SKIN => meta.playData.noteStyle ?? "funkin",
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
