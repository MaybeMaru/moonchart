package moonchart.formats.fnf.legacy;

import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.backend.Util;
import haxe.Json;

typedef FpsPlusJsonFormat = FNFLegacyFormat &
{
	stage:String,
	gf:String
}

typedef FpsPlusEventsJson =
{
	events:
	{
		events:Array<FpsPlusEvent>
	}
}

abstract FpsPlusEvent(Array<Dynamic>) from Array<Dynamic> to Array<Dynamic>
{
	public var section(get, never):Int;
	public var time(get, never):Float;
	public var name(get, never):String;

	function get_section():Int
	{
		return this[0];
	}

	function get_time():Float
	{
		return this[1];
	}

	function get_name():String
	{
		return this[3];
	}
}

class FNFFpsPlus extends FNFLegacyBasic<FpsPlusJsonFormat>
{
	var events:FpsPlusEventsJson;

	override function fromBasicFormat(chart:BasicChart, ?diff:String):FNFFpsPlus
	{
		var basic = super.fromBasicFormat(chart, diff);
		var data = basic.data;

		var events:Array<FpsPlusEvent> = [];

		this.events = {
			events: {
				events: events
			}
		}

		this.meta = this.events;

		var basicEvents = chart.data.events;
		if (basicEvents.length > 0)
		{
			var eventMeasures = Timing.divideNotesToMeasures([], basicEvents, chart.meta.bpmChanges);
			for (i in 0...eventMeasures.length)
			{
				for (basicEvent in eventMeasures[i].events)
				{
					// FPS Plus events meta have the events section index for whatever reason
					var plusEvent:FpsPlusEvent = [i, basicEvent.time, 0, basicEvent.name];
					events.push(plusEvent);
				}
			}
		}

		data.song.gf = chart.meta.extraData.get(PLAYER_3) ?? "";
		data.song.stage = chart.meta.extraData.get(STAGE) ?? "";

		return cast basic;
	}

	override function getEvents():Array<BasicEvent>
	{
		var events = super.getEvents();

		for (plusEvent in this.events.events.events)
		{
			var time:Float = plusEvent.time;
			var name:String = plusEvent.name;

			events.push({
				time: time,
				name: name,
				data: {}
			});
		}

		return events;
	}

	override function fromFile(path:String, ?meta:String, ?diff:String):FNFFpsPlus
	{
		var format:FNFFpsPlus = cast super.fromFile(path, meta, diff);

		if (meta != null && meta.length > 0)
		{
			this.events = Json.parse(Util.getText(meta));
			this.meta = this.events;
		}

		return format;
	}
}
