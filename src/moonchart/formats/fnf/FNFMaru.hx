package moonchart.formats.fnf;

import moonchart.backend.Optimizer;
import haxe.Json;
import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.BasicFormat.BasicChart;
import moonchart.formats.fnf.legacy.FNFLegacy;

typedef FNFMaruJsonFormat =
{
	song:String,
	notes:Array<FNFMaruSection>,
	bpm:Float,
	speed:Float,
	offsets:Array<Int>,
	stage:String,
	players:FNFMaruPlayers,
}

typedef FNFMaruSection =
{
	var sectionNotes:Array<FNFLegacyNote>;
	var sectionEvents:Array<FNFMaruEvent>;
	var mustHitSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
}

// TODO: maru meta
typedef FNFMaruMetaFormat = {}

abstract FNFMaruEvent(Array<Dynamic>) from Array<Dynamic> to Array<Dynamic>
{
	public var time(get, never):Float;
	public var name(get, never):String;
	public var values(get, never):Array<Dynamic>;

	function get_time():Float
	{
		return this[0];
	}

	function get_name():String
	{
		return this[1];
	}

	function get_values():Array<Dynamic>
	{
		return this[2];
	}
}

abstract FNFMaruPlayers(Array<String>) from Array<String> to Array<String>
{
	public var bf(get, never):String;
	public var dad(get, never):String;
	public var gf(get, never):String;

	function get_bf():String
	{
		return this[0];
	}

	function get_dad():String
	{
		return this[1];
	}

	function get_gf():String
	{
		return this[2];
	}
}

// Pretty similar to FNFLegacy although with enough changes to need a seperate implementation
// TODO: remove unused variables in stringify

class FNFMaru extends BasicFormat<{song:FNFMaruJsonFormat}, FNFMaruMetaFormat>
{
	// Easier to work with, same format pretty much lol
	var legacy:FNFLegacy;

	public function new(?data:{song:FNFMaruJsonFormat}, ?diff:String)
	{
		super({timeFormat: MILLISECONDS, supportsEvents: true});
		this.data = data;
		this.diff = diff;

		legacy = new FNFLegacy();
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:String):FNFMaru
	{
		diff ??= this.diff;
		legacy.fromBasicFormat(chart, diff);
		var fnfData = legacy.data.song;

		var diffChart = Timing.resolveDiffNotes(chart, diff);
		var measures = Timing.divideNotesToMeasures(diffChart, chart.data.events, chart.meta.bpmChanges);

		var maruNotes:Array<FNFMaruSection> = [];

		for (i in 0...fnfData.notes.length)
		{
			var section = fnfData.notes[i];

			// Copy pasted lol
			var maruSection:FNFMaruSection = {
				sectionNotes: section.sectionNotes,
				sectionEvents: [],
				mustHitSection: section.mustHitSection,
				changeBPM: section.changeBPM,
				bpm: section.bpm
			}

			// Push events to the section
			if (i < measures.length)
			{
				for (event in measures[i].events)
				{
					maruSection.sectionEvents.push(resolveMaruEvent(event));
				}
			}

			maruNotes.push(maruSection);
		}

		this.data = {
			song: {
				song: fnfData.song,
				bpm: fnfData.bpm,
				notes: maruNotes,
				offsets: [chart.meta.extraData.get(OFFSET) ?? 0, chart.meta.extraData.get(OFFSET) ?? 0],
				speed: fnfData.speed,
				stage: chart.meta.extraData.get(STAGE) ?? "",
				players: [fnfData.player1, fnfData.player2, chart.meta.extraData.get(PLAYER_3) ?? ""]
			}
		}

		return this;
	}

	function resolveMaruEvent(event:BasicEvent):FNFMaruEvent
	{
		var values:Array<Dynamic> = [];

		if (event.data.VALUE_1 != null)
		{
			values.push(event.data.VALUE_1);
			values.push(event.data.VALUE_2);
		}
		else if (event.data.array != null)
		{
			values = event.data.array.copy();
		}
		else
		{
			var fields = Reflect.fields(event.data);
			fields.sort((a, b) -> return Util.sortString(a, b));

			for (field in fields)
			{
				values.push(Reflect.field(event.data, field));
			}
		}

		return [event.time, event.name, values];
	}

	// TODO: do this without copy pasting fnf legacy

	override function getNotes():Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var stepCrochet = Timing.stepCrochet(data.song.bpm, 4);

		for (section in data.song.notes)
		{
			if (section.changeBPM)
			{
				stepCrochet = Timing.stepCrochet(section.bpm, 4);
			}

			for (note in section.sectionNotes)
			{
				var lane:Int = FNFLegacy.mustHitLane(section.mustHitSection, note.lane);
				var length:Float = note.length > 0 ? note.length + stepCrochet : 0;
				var type:String = FNFLegacy.resolveNoteType(note);

				notes.push({
					time: note.time,
					lane: lane,
					length: length,
					type: type
				});
			}
		}

		Timing.sortNotes(notes);

		return notes;
	}

	override function getEvents():Array<BasicEvent>
	{
		var events:Array<BasicEvent> = [];

		var time:Float = 0;
		var crochet = Timing.measureCrochet(data.song.bpm, 4);

		for (section in data.song.notes)
		{
			events.push(FNFLegacy.makeMustHitSectionEvent(time, section.mustHitSection));

			for (event in section.sectionEvents)
			{
				var basicEvent:BasicEvent = {
					time: event.time,
					name: event.name,
					data: {
						array: event.values
					}
				}
				events.push(basicEvent);
			}

			if (section.changeBPM)
			{
				crochet = Timing.measureCrochet(section.bpm, 4);
			}

			time += crochet;
		}

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];
		var song = data.song;

		var time:Float = 0.0;
		var bpm:Float = song.bpm;

		bpmChanges.push({
			time: time,
			bpm: bpm,
			beatsPerMeasure: 4,
			stepsPerBeat: 4
		});

		for (section in song.notes)
		{
			if (section.changeBPM)
			{
				bpm = section.bpm;
				bpmChanges.push({
					time: time,
					bpm: bpm,
					beatsPerMeasure: 4,
					stepsPerBeat: 4
				});
			}

			time += Timing.measureCrochet(bpm, 4);
		}

		Timing.sortBPMChanges(bpmChanges);

		return {
			title: song.song,
			bpmChanges: bpmChanges,
			extraData: [
				PLAYER_1 => song.players.bf,
				PLAYER_2 => song.players.dad,
				PLAYER_3 => song.players.gf,
				SCROLL_SPEED => song.speed,
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

	public override function fromFile(path:String, ?meta:String, ?diff:String):FNFMaru
	{
		return fromJson(Util.getText(path), meta, diff ?? this.diff);
	}

	public function fromJson(data:String, ?meta:String, diff:String):FNFMaru
	{
		this.diff = diff;
		this.data = Json.parse(data);
		this.meta = (meta != null) ? Json.parse(meta) : null;

		// Maru format turns null some values for filesize reasons
		for (section in this.data.song.notes)
		{
			Optimizer.addDefaultValues(section, {
				bpm: 0,
				changeBPM: false,
				mustHitSection: false,
				sectionNotes: [],
				sectionEvents: []
			});
		}

		return this;
	}
}
