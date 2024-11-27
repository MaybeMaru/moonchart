package moonchart.formats.fnf.legacy;

import moonchart.backend.FormatData;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.backend.Util;
import haxe.Json;

using StringTools;

typedef FpsPlusJsonFormat = FNFLegacyFormat &
{
	stage:String,
	gf:String
}

// TODO: add fps+ metadata
typedef FpsPlusMetaJson =
{
	name:String,
	artist:String,
	album:String,
	difficulties:Array<Int>
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

	inline function get_section():Int
		return this[0];

	inline function get_time():Float
		return this[1];

	inline function get_name():String
		return this[3];
}

class FNFFpsPlus extends FNFLegacyBasic<FpsPlusJsonFormat>
{
	var events:FpsPlusEventsJson;
	var plusMeta:FpsPlusMetaJson;

	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_LEGACY_FPS_PLUS,
			name: "FNF (FPS +)",
			description: "Similar to FNF Legacy but with some extra metadata.",
			extension: "json",
			formatFile: FNFLegacy.formatFile,
			hasMetaFile: POSSIBLE,
			metaFileExtension: "json",
			specialValues: ['"gf":'],
			findMeta: (files) ->
			{
				for (file in files)
				{
					if (Util.getText(file).contains("events"))
						return file;
				}
				return files[0];
			},
			handler: FNFFpsPlus
		}
	}

	public function new(?data:{song:FpsPlusJsonFormat})
	{
		super(data);
		this.formatMeta.supportsEvents = true;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFFpsPlus
	{
		var basic = super.fromBasicFormat(chart, diff);
		var data = basic.data;

		var events:Array<FpsPlusEvent> = [];
		this.meta = this.events = makeFpsPlusEventsJson(events);

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
		var emptyData:Dynamic = {};

		for (plusEvent in this.events.events.events)
		{
			var time:Float = plusEvent.time;
			var name:String = plusEvent.name;

			events.push({
				time: time,
				name: name,
				data: emptyData
			});
		}

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var meta = super.getChartMeta();
		meta.extraData.set(PLAYER_3, data.song.gf);
		meta.extraData.set(STAGE, data.song.stage);
		return meta;
	}

	function makeFpsPlusEventsJson(events:Array<FpsPlusEvent>):FpsPlusEventsJson
	{
		return {
			events: {
				events: events
			}
		}
	}

	override function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFLegacyBasic<FpsPlusJsonFormat>
	{
		super.fromJson(data, meta, diff);

		// TODO: add support for events and meta json's
		final hasMeta:Bool = (meta != null && meta.length > 0);
		this.events = hasMeta ? Json.parse(Util.getText(meta)) : makeFpsPlusEventsJson([]);
		this.meta = this.events;

		return this;
	}
}
