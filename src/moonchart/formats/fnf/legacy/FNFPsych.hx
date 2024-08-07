package moonchart.formats.fnf.legacy;

import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;
import haxe.Json;

typedef PsychEvent = Array<Dynamic>;

// TODO: implement this
typedef PsychSection = FNFLegacySection &
{
	sectionBeats:Float,
	gfSection:Bool
}

typedef PsychJsonFormat = FNFLegacyFormat &
{
	events:Array<PsychEvent>,
	gfVersion:String,
	stage:String,
	/*
		?gameOverChar:String,
		?gameOverSound:String,
		?gameOverLoop:String,
		?gameOverEnd:String,

		?disableNoteRGB:Bool,
		?arrowSkin:String,
		?splashSkin:String
	 */
}

class FNFPsych extends FNFLegacyBasic<PsychJsonFormat>
{
	public function new(?data:{song:PsychJsonFormat}, ?diff:String)
	{
		super(data, diff);
		this.formatMeta.supportsEvents = true;
	}

	override function fromFile(path:String, ?meta:String, ?diff:String):FNFPsych
	{
		var format:FNFPsych = cast super.fromFile(path, meta, diff);
		pushPsychEventNotes(format.data.song, format.data.song);

		if (meta != null && meta.length > 0)
		{
			var metadata:{song:PsychJsonFormat} = Json.parse(Util.getText(meta));

			if (metadata.song.events != null)
			{
				for (event in metadata.song.events)
					format.data.song.events.push(event);
			}

			if (metadata.song.notes != null)
			{
				pushPsychEventNotes(metadata.song, format.data.song);
			}
		}

		return format;
	}

	function pushPsychEventNotes(origin:PsychJsonFormat, target:PsychJsonFormat)
	{
		for (section in origin.notes)
		{
			var removeNotes:Array<FNFLegacyNote> = [];

			for (note in section.sectionNotes)
			{
				if (note.lane == -1)
				{
					var eventData:Array<Array<String>> = [[Std.string(note[2]), Std.string(note[3]), Std.string(note[4])]];
					target.events.push([note.time, eventData]);
					removeNotes.push(note);
				}
			}

			for (note in removeNotes)
			{
				section.sectionNotes.remove(note);
			}
		}
	}

	function resolvePsychEvent(event:BasicEvent):PsychEvent
	{
		var values:Array<Dynamic> = Util.resolveEventValues(event);

		var value1:Dynamic = values[0] ?? "";
		var value2:Dynamic = values[1] ?? "";

		return [event.time, [[event.name, Std.string(value1), Std.string(value2)]]];
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:String):FNFPsych
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

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var meta = super.getChartMeta();
		meta.extraData.set(PLAYER_3, data.song.gfVersion);
		meta.extraData.set(STAGE, data.song.stage);
		return meta;
	}
}
