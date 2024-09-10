package moonchart.formats.fnf;

import moonchart.backend.FormatData;
import moonchart.backend.Util;
import haxe.Json;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;

using StringTools;

typedef FNFKadeFormat =
{
	songName:String,
	songId:String,
	chartVersion:String,

	offset:Int,
	notes:Array<FNFKadeSection>,
	eventObjects:Array<FNFKadeEvent>,
	speed:Float,
	bpm:Float,

	player1:String,
	player2:String,
	gfVersion:String,
	stage:String,

	needsVoices:Bool,
	validScore:Bool,
	noteStyle:String,
}

typedef FNFKadeSection =
{
	startTime:Float,
	endTime:Float,
	sectionNotes:Array<FNFKadeNote>,
	lengthInSteps:Int,
	mustHitSection:Bool
}

abstract FNFKadeNote(Array<Dynamic>) from Array<Dynamic> to Array<Dynamic>
{
	public var time(get, never):Float;
	public var lane(get, never):Int;
	public var length(get, never):Float;
	public var isAlt(get, never):Bool;
	public var beat(get, never):Float;

	inline function get_time():Float
	{
		return this[0];
	}

	inline function get_lane():Int
	{
		return this[1];
	}

	inline function get_length():Float
	{
		return this[2];
	}

	inline function get_isAlt():Bool
	{
		return this[3];
	}

	inline function get_beat():Float
	{
		return this[4];
	}
}

typedef FNFKadeEvent =
{
	name:String,
	position:Float,
	value:Float,
	type:String
}

typedef FNFKadeMeta =
{
	name:String,
	?offset:Int,
}

// NOTE: This is the Kade Engine 1.8 format
// For older versions of Kade Engine use FNFLegacy instead
class FNFKade extends BasicFormat<{song:FNFKadeFormat}, FNFKadeMeta>
{
	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_KADE,
			name: "FNF (Kade Engine)",
			description: "",
			extension: "json",
			hasMetaFile: POSSIBLE,
			metaFileExtension: "json",
			specialValues: ['"noteStyle":', '"chartVersion":', '"eventObjects":'],
			handler: FNFKade
		}
	}

	public static inline var KADE_INIT_BPM:String = "Init BPM";
	public static inline var KADE_BPM_CHANGE:String = "BPM Change";

	var legacy:FNFLegacy;

	public function new(?data:{song:FNFKadeFormat})
	{
		super({timeFormat: MILLISECONDS, supportsDiffs: false, supportsEvents: false}); // keeping events false for now
		this.data = data;

		legacy = new FNFLegacy();
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFKade
	{
		legacy.fromBasicFormat(chart, diff);
		var fnfData = legacy.data.song;

		var chartResolve = resolveDiffsNotes(chart, diff);
		var diff:String = chartResolve.diffs[0];
		var diffChart:Array<BasicNote> = chartResolve.notes.get(diff);

		var measures = Timing.divideNotesToMeasures(diffChart, chart.data.events, chart.meta.bpmChanges);
		var meta = chart.meta;

		var kadeSections:Array<FNFKadeSection> = [];

		for (i in 0...fnfData.notes.length)
		{
			var fnfSection = fnfData.notes[i];
			var basicSection = measures[i];

			var kadeNotes:Array<FNFKadeNote> = [];

			for (note in fnfSection.sectionNotes)
			{
				var kadeNote:FNFKadeNote = [note.time, note.lane, note.length, fnfSection.altAnim, 0];
				kadeNotes.push(kadeNote);
			}

			var kadeSection:FNFKadeSection = {
				startTime: basicSection.startTime,
				endTime: basicSection.endTime,
				sectionNotes: kadeNotes,
				lengthInSteps: fnfSection.lengthInSteps,
				mustHitSection: fnfSection.mustHitSection,
			}

			kadeSections.push(kadeSection);
		}

		var kadeEvents:Array<FNFKadeEvent> = [
			{
				name: KADE_INIT_BPM,
				position: 0,
				value: fnfData.bpm,
				type: KADE_BPM_CHANGE
			}
		];

		/* Kade engine 1.8 is hardcoded to have only 2 event types, so idk if i should add this,,.
			chart.data.events = legacy.filterEvents(chart.data.events);

			for (event in chart.data.events)
			{
				kadeEvents.push({
					name: "Ported Events",
					position: event.time,
					value: 0,
					type: event.name
				});
		}*/

		this.data = {
			song: {
				songName: fnfData.song,
				songId: resolveKadeId(fnfData.song),
				chartVersion: "KE1",

				offset: Std.int(meta.offset ?? 0.0),
				notes: kadeSections,
				eventObjects: kadeEvents,
				speed: meta.scrollSpeeds.get(diff) ?? 1.0,
				bpm: fnfData.bpm,

				player1: meta.extraData.get(PLAYER_1) ?? "bf",
				player2: meta.extraData.get(PLAYER_2) ?? "dad",
				gfVersion: meta.extraData.get(PLAYER_3) ?? "gf",
				stage: meta.extraData.get(STAGE) ?? "stage",

				needsVoices: meta.extraData.get(NEEDS_VOICES) ?? true,
				validScore: true,
				noteStyle: "normal" // TODO: make this compatible between formats that support skins
			}
		}

		return this;
	}

	function resolveKadeId(title:String):String
	{
		return title.toLowerCase().replace(" ", "").replace(".", "");
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		for (section in data.song.notes)
		{
			for (note in section.sectionNotes)
			{
				var lane:Int = FNFLegacy.mustHitLane(section.mustHitSection, note.lane);
				var type:String = note.isAlt ? ALT_ANIM : DEFAULT;

				notes.push({
					time: note.time,
					lane: lane,
					length: note.length,
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
		var lastMustHit:Bool = FNFLegacy.FNF_LEGACY_DEFAULT_MUSTHIT;

		for (section in data.song.notes)
		{
			if (lastMustHit != section.mustHitSection)
			{
				events.push(FNFLegacy.makeMustHitSectionEvent(section.startTime, section.mustHitSection));
				lastMustHit = section.mustHitSection;
			}
		}

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		for (event in data.song.eventObjects)
		{
			if (event.name == KADE_INIT_BPM && event.type == KADE_BPM_CHANGE)
			{
				bpmChanges.push({
					time: event.position,
					bpm: event.value,
					stepsPerBeat: 4,
					beatsPerMeasure: 4
				});
			}
		}

		return {
			title: data.song.songName,
			bpmChanges: bpmChanges,
			offset: data.song.offset,
			scrollSpeeds: [diffs[0] => data.song.speed],
			extraData: [
				PLAYER_1 => data.song.player1,
				PLAYER_2 => data.song.player2,
				PLAYER_3 => data.song.gfVersion,
				STAGE => data.song.stage,
				NEEDS_VOICES => data.song.needsVoices
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

	public override function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):FNFKade
	{
		return fromJson(Util.getText(path), meta, diff);
	}

	public function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFKade
	{
		this.diffs = diff;
		this.data = Json.parse(data);
		if (meta != null)
		{
			this.meta = Json.parse(meta);

			if (this.meta.name != null)
				this.data.song.songName = this.meta.name;

			if (this.meta.offset != null)
				this.data.song.offset = this.meta.offset;
		}
		else
		{
			this.meta = {
				name: this.data.song.songName,
				offset: this.data.song.offset
			}
		}
		return this;
	}
}
