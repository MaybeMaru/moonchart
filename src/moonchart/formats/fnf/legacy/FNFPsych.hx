package moonchart.formats.fnf.legacy;

import moonchart.backend.Timing;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;
import haxe.Json;

typedef PsychEvent = Array<Dynamic>;

typedef PsychSection = FNFLegacySection &
{
	?sectionBeats:Float,
	?gfSection:Bool // TODO: add as an event probably
}

typedef PsychJsonFormat = FNFLegacyFormat &
{
	?events:Array<PsychEvent>,
	?gfVersion:String,
	stage:String,

	?gameOverChar:String,
	?gameOverSound:String,
	?gameOverLoop:String,
	?gameOverEnd:String,

	?disableNoteRGB:Bool,
	?arrowSkin:String,
	?splashSkin:String,

	?player3:String
}

enum abstract FNFPsychEvent(String) from String to String
{
	var GF_SECTION = "FNF_PSYCH_GF_SECTION";
}

class FNFPsych extends FNFLegacyBasic<PsychJsonFormat>
{
	public function new(?data:{song:PsychJsonFormat})
	{
		super(data);
		this.formatMeta.supportsEvents = true;
	}

	function resolvePsychEvent(event:BasicEvent):PsychEvent
	{
		var values:Array<Dynamic> = Util.resolveEventValues(event);

		var value1:Dynamic = values[0] ?? "";
		var value2:Dynamic = values[1] ?? "";

		return [event.time, [[event.name, Std.string(value1), Std.string(value2)]]];
	}

	// TODO: add GF_SECTION event inputs
	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFPsych
	{
		var basic = super.fromBasicFormat(chart, diff);
		var data = basic.data;

		data.song.events = [];
		for (basicEvent in chart.data.events)
		{
			data.song.events.push(resolvePsychEvent(basicEvent));
		}

		data.song.gfVersion = chart.meta.extraData.get(PLAYER_3) ?? "";
		data.song.stage = chart.meta.extraData.get(STAGE) ?? "";

		return cast basic;
	}

	override function getEvents():Array<BasicEvent>
	{
		var events = super.getEvents();

		// Push GF section events
		var lastGfSection:Bool = false;
		forEachSection(data.song.notes, (section, startTime, endTime) ->
		{
			var psychSection:PsychSection = cast section;

			var gfSection:Bool = (psychSection.gfSection ?? false);
			if (gfSection != lastGfSection)
			{
				events.push(makeGfSectionEvent(startTime, gfSection));
				lastGfSection = gfSection;
			}
		});

		// Push normal psych events
		for (baseEvent in data.song.events)
		{
			var time:Float = baseEvent[0];
			var pack:Array<Array<String>> = baseEvent[1];
			for (event in pack)
			{
				events.push({
					time: time,
					name: event[0],
					data: {
						VALUE_1: event[1],
						VALUE_2: event[2]
					}
				});
			}
		}

		Timing.sortEvents(events);
		return events;
	}

	override function filterEvents(events:Array<BasicEvent>):Array<BasicEvent>
	{
		return super.filterEvents(events).filter((event) -> return event.name != GF_SECTION);
	}

	function makeGfSectionEvent(time:Float, gfSection:Bool):BasicEvent
	{
		return {
			time: time,
			name: GF_SECTION,
			data: {
				gfSection: gfSection
			}
		}
	}

	override function getChartMeta():BasicMetaData
	{
		var meta = super.getChartMeta();
		meta.extraData.set(PLAYER_3, data.song.gfVersion ?? data.song.player3);
		meta.extraData.set(STAGE, data.song.stage);
		return meta;
	}

	override function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFPsych
	{
		super.fromJson(data, meta, diff);
		updateEvents(this.data.song, meta != null ? Json.parse(meta).song : null);
		return this;
	}

	override function sectionBeats(?section:FNFLegacySection):Float
	{
		var psychSection:Null<PsychSection> = cast section;
		return psychSection?.sectionBeats ?? super.sectionBeats(section);
	}

	// Merge the events meta file and convert -1 lane notes to events
	function updateEvents(song:PsychJsonFormat, ?events:PsychJsonFormat):Void
	{
		var songNotes:Array<FNFLegacySection> = song.notes;
		song.events ??= [];

		if (events != null)
		{
			songNotes = songNotes.concat(events.notes ?? []);
			song.events = song.events.concat(events.events ?? []);
		}

		for (section in songNotes)
		{
			var eventNotes:Array<FNFLegacyNote> = [];

			for (note in section.sectionNotes)
			{
				if (note.lane == -1)
				{
					song.events.push([note.time, [[note[2], note[3], note[4]]]]);
					eventNotes.push(note);
				}
			}

			for (eventNote in eventNotes)
			{
				section.sectionNotes.remove(eventNote);
			}
		}
	}
}
