package moonchart.formats.fnf;

import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy.FNFLegacyEvent;
import moonchart.formats.fnf.legacy.FNFLegacy.FNFLegacyMetaValues;
import haxe.Json;

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
	bpm:Float
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

class FNFVSlice extends BasicFormat<FNFVSliceFormat, FNFVSliceMeta>
{
	public static inline var VSLICE_FOCUS_EVENT:String = "FocusCamera";
	public static inline var VSLICE_DEFAULT_NOTE:String = "normal";

	public static inline var VSLICE_CHART_VERSION:String = "2.0.0";
	public static inline var VSLICE_META_VERSION:String = "2.2.2";
	public static inline var VSLICE_MANIFEST_VERSION:String = "1.0.0";

	public function new(?data:FNFVSliceFormat, ?meta:FNFVSliceMeta)
	{
		super({timeFormat: MILLISECONDS, supportsEvents: true});
		this.data = data;
		this.meta = meta;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFVSlice
	{
		var chartResolve = resolveDiffsNotes(chart, diff).notes;
		var meta = chart.meta;

		var notes:Dynamic = {};
		var scrollSpeed:Dynamic = {};

		var basicBpmChanges = meta.bpmChanges.copy();
		var timeChanges:Array<FNFVSliceTimeChange> = [];
		timeChanges.push({
			t: -1,
			bpm: basicBpmChanges.shift().bpm
		});

		// TODO: implement time signatures to vslice
		for (change in basicBpmChanges)
		{
			timeChanges.push({
				t: change.time,
				bpm: change.bpm
			});
		}

		timeChanges.sort((a, b) -> return Util.sortValues(a.t, b.t));

		for (chartDiff => chart in chartResolve)
		{
			var noteTimeChanges = timeChanges.copy();

			var change = noteTimeChanges.shift();
			var stepCrochet:Float = Timing.stepCrochet(change.bpm, 4);
			var chartNotes:Array<FNFVSliceNote> = [];

			for (note in chart)
			{
				var time = note.time;
				var length = note.length;

				// Find the last bpm change
				while (noteTimeChanges.length > 0 && noteTimeChanges[0].t <= time)
				{
					change = noteTimeChanges.shift();
					stepCrochet = Timing.stepCrochet(change.bpm, 4);
				}

				// Offset sustain length, vslice starts a step crochet later
				chartNotes.push({
					t: time,
					d: note.lane,
					l: length > 0 ? length - stepCrochet : 0,
					k: note.type
				});
			}
			Reflect.setField(notes, chartDiff, chartNotes);
			Reflect.setField(scrollSpeed, chartDiff, meta.extraData.get(SCROLL_SPEED) ?? 1.0);
		}

		var events:Array<FNFVSliceEvent> = [];
		for (event in chart.data.events)
		{
			events.push(switch (event.name)
			{
				case MUST_HIT_SECTION:
					{
						t: event.time,
						e: VSLICE_FOCUS_EVENT,
						v: {
							char: (event.data.mustHitSection ?? true) ? 0 : 1
						}
					}
				default:
					{
						t: event.time,
						e: event.name,
						v: event.data
					}
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
				songVariations: [],
				noteStyle: "funkin"
			},
			songName: meta.title,
			offsets: {
				vocals: vocalsOffset,
				instrumental: extra.get(OFFSET) ?? 0,
				altInstrumentals: {} // TODO: whatever this is
			},
			timeChanges: timeChanges,
			generatedBy: Util.version,
			version: VSLICE_META_VERSION
		}

		return this;
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var chartNotes:Array<FNFVSliceNote> = Reflect.field(data.notes, diff);
		if (chartNotes == null)
		{
			throw "Couldn't find Funkin VSlice notes for difficulty " + (diff ?? "null");
			return null;
		}

		var timeChanges = meta.timeChanges.copy();

		var change = timeChanges.shift();
		var stepCrochet = Timing.stepCrochet(change.bpm, 4);

		for (note in chartNotes)
		{
			var time = note.t;
			var length = note.l;
			var type = note.k ?? "";

			// Find last bpm change
			while (timeChanges.length > 0 && timeChanges[0].t <= time)
			{
				change = timeChanges.shift();
				stepCrochet = Timing.stepCrochet(change.bpm, 4);
			}

			notes.push({
				time: time,
				lane: note.d,
				length: length > 0 ? length + stepCrochet : 0,
				type: type != VSLICE_DEFAULT_NOTE ? type : ""
			});
		}

		Timing.sortNotes(notes);

		return notes;
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

		return {
			title: meta.songName,
			bpmChanges: bpmChanges,
			extraData: [
				PLAYER_1 => chars.player,
				PLAYER_2 => chars.opponent,
				PLAYER_3 => chars.girlfriend,
				STAGE => meta.playData.stage,
				SCROLL_SPEED => Reflect.field(data.scrollSpeed, diffs[0]) ?? 1.0,
				OFFSET => meta.offsets?.instrumental ?? 0.0,
				VOCALS_OFFSET => vocalsOffset,
				NEEDS_VOICES => true,
				SONG_ARTIST => meta.artist,
				SONG_CHARTER => meta.charter
			]
		}
	}

	override function stringify()
	{
		return {
			data: Json.stringify(data, "\t"),
			meta: Json.stringify(meta, "\t")
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
