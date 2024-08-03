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
	playData:FNFVSlicePlayData,
	songName:String,
	timeChanges:Array<FNFVSliceTimeChange>
}

typedef FNFVSliceTimeChange =
{
	// TODO: look what the other variables do
	t:Float,
	bpm:Float
}

typedef FNFVSlicePlayData =
{
	characters:
	{
		player:String, girlfriend:String, opponent:String
	},
	difficulties:Array<String>,
	stage:String
}

class FNFVSlice extends BasicFormat<FNFVSliceFormat, FNFVSliceMeta>
{
	public static inline var VSLICE_FOCUS_EVENT:String = "FocusCamera";
	public static inline var VSLICE_DEFAULT_NOTE:String = "normal";

	public function new(?data:FNFVSliceFormat, ?meta:FNFVSliceMeta, ?diff:String)
	{
		super({timeFormat: MILLISECONDS, supportsEvents: true});
		this.data = data;
		this.meta = meta;
		this.diff = diff;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:String):FNFVSlice
	{
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

		for (diff => chart in chart.data.diffs)
		{
			var timeChangeIndex:Int = 1;
			var stepCrochet:Float = Timing.stepCrochet(timeChanges[0].bpm, 4);
			var chartNotes:Array<FNFVSliceNote> = [];

			for (note in chart)
			{
				var time = note.time;
				var length = note.length;

				// Find the last bpm change
				if (timeChangeIndex < timeChanges.length)
				{
					while (time >= timeChanges[timeChangeIndex].t)
					{
						timeChangeIndex++;
						var safeIndex:Int = Util.minInt(timeChangeIndex, timeChanges.length - 1);
						stepCrochet = Timing.stepCrochet(timeChanges[safeIndex].bpm, 4);
					}
				}

				// Offset sustain length, vslice starts a step crochet later
				chartNotes.push({
					t: time,
					d: note.lane,
					l: length > 0 ? length - stepCrochet : 0,
					k: note.type
				});
			}
			Reflect.setField(notes, diff, chartNotes);
			Reflect.setField(scrollSpeed, diff, meta.extraData.get(SCROLL_SPEED) ?? 1.0);
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
			version: "",
			scrollSpeed: scrollSpeed,
			notes: notes,
			events: events
		}

		var difficulties:Array<String> = [];
		for (i in chart.data.diffs.keys())
			difficulties.push(i);

		this.meta = {
			playData: {
				stage: meta.extraData.get(STAGE) ?? "stage",
				difficulties: difficulties,
				characters: {
					player: meta.extraData.get(PLAYER_1) ?? "bf",
					girlfriend: meta.extraData.get(PLAYER_2) ?? "dad",
					opponent: meta.extraData.get(PLAYER_3) ?? "gf"
				}
			},
			songName: meta.title,
			timeChanges: timeChanges
		}

		return this;
	}

	override function getNotes():Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var chartNotes:Array<FNFVSliceNote> = Reflect.field(data.notes, Timing.resolveDiff(diff));
		if (chartNotes == null)
		{
			throw "Couldn't find Funkin VSlice notes for difficulty " + (diff ?? "null");
			return null;
		}

		var timeChanges = meta.timeChanges.copy();
		var stepCrochet = Timing.stepCrochet(timeChanges.shift().bpm, 4);
		var timeIndex = 0;

		for (note in chartNotes)
		{
			var time = note.t;
			var length = note.l;
			var type = note.k ?? "";

			if (timeIndex < timeChanges.length)
			{
				while (time >= timeChanges[timeIndex].t)
				{
					timeIndex++;
					var safeIndex:Int = Util.minInt(timeIndex, timeChanges.length - 1);
					stepCrochet = Timing.stepCrochet(timeChanges[safeIndex].bpm, 4);
				}
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

		return {
			title: meta.songName,
			bpmChanges: bpmChanges,
			extraData: [
				PLAYER_1 => chars.player,
				PLAYER_2 => chars.opponent,
				PLAYER_3 => chars.girlfriend,
				STAGE => meta.playData.stage,
				SCROLL_SPEED => Reflect.field(data.scrollSpeed, diff) ?? 1.0,
				NEEDS_VOICES => true
			]
		}
	}

	override function stringify()
	{
		return {
			data: Json.stringify(data),
			meta: Json.stringify(meta)
		}
	}

	public override function fromFile(path:String, ?meta:String, ?diff:String):FNFVSlice
	{
		return fromJson(Util.getText(path), Util.getText(meta), diff);
	}

	public function fromJson(data:String, ?meta:String, diff:String):FNFVSlice
	{
		this.diff = diff;
		this.data = Json.parse(data);
		this.meta = Json.parse(meta);
		return this;
	}
}
