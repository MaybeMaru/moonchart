package moonchart.formats;

typedef BasicTimingObject =
{
	time:Float
}

typedef BasicNote = BasicTimingObject &
{
	lane:Int,
	length:Float,
	type:String
}

typedef BasicEvent = BasicTimingObject &
{
	name:String,
	data:Dynamic
}

typedef BasicBPMChange = BasicTimingObject &
{
	bpm:Float,
	beatsPerMeasure:Float,
	stepsPerBeat:Float
}

typedef BasicMeasure =
{
	notes:Array<BasicNote>,
	events:Array<BasicEvent>,
	bpm:Float,
	beatsPerMeasure:Float,
	stepsPerBeat:Float,
	startTime:Float,
	endTime:Float,
	length:Float,
	snap:Int
}

typedef BasicChartDiffs = Map<String, Array<BasicNote>>;

typedef BasicChart =
{
	data:BasicChartData,
	meta:BasicMetaData
}

typedef BasicChartData =
{
	diffs:BasicChartDiffs,
	events:Array<BasicEvent>,
}

typedef BasicMetaData =
{
	title:String,
	bpmChanges:Array<BasicBPMChange>,
	extraData:Map<String, Dynamic> // Mainly for extra bullshit variables that may not exist among all formats
}

enum abstract TimeFormat(Int)
{
	var MILLISECONDS;
	var SECONDS;
	var STEPS; // Stepmania
	var TICKS; // Guitar hero
}

enum abstract BasicMetaValues(String) from String to String
{
	var SCROLL_SPEED = "SCROLL_SPEED";
	var OFFSET = "OFFSET";
	var SONG_ARTIST = "SONG_ARTIST"; // TODO: implement to all formats
	var SONG_CHARTER = "SONG_CHARTER";
}

typedef BasicFormatMetadata =
{
	timeFormat:TimeFormat,
	supportsEvents:Bool // TODO: double check later for all formats, im too ill to check rn
}

abstract class BasicFormat<D, M>
{
	public var data:D;
	public var meta:M;
	public var diff:Null<String>;

	public var formatMeta(default, null):BasicFormatMetadata;

	public function new(formatMeta:BasicFormatMetadata)
	{
		this.formatMeta = formatMeta ?? {
			timeFormat: MILLISECONDS,
			supportsEvents: true
		};
	}

	public function fromFile(path:String, ?meta:String, ?diff:String):BasicFormat<D, M>
	{
		throw "fromFile needs to be implemented in this format!";
		return null;
	}

	public function fromBasicFormat(chart:BasicChart, ?diff:String):Dynamic
	{
		throw "fromBasicFormat needs to be implemented in this format!";
		return null;
	}

	public function fromFormat(format:BasicFormat<{}, {}>, ?diff:String):Dynamic
	{
		fromBasicFormat(format.toBasicFormat(), diff);
		return this;
	}

	public function toBasicFormat():BasicChart
	{
		return {
			data: getChartData(),
			meta: getChartMeta()
		};
	}

	public function stringify():{data:Null<String>, meta:Null<String>}
	{
		throw "stringify needs to be implemented in this format!";
		return null;
	}

	public function getNotes():Array<BasicNote>
	{
		return [];
	}

	public function getEvents():Array<BasicEvent>
	{
		if (formatMeta.supportsEvents)
		{
			throw "getEvents needs to be implemented in this format!";
			return null;
		}

		return [];
	}

	public function getChartMeta():BasicMetaData
	{
		throw "getChartMeta needs to be implemented in this format!";
		return null;
	}

	public static inline var DEFAULT_DIFF:String = "DEFAULT_DIFF";

	public function getChartData():BasicChartData
	{
		var diffs = new BasicChartDiffs();
		diffs.set(diff ?? DEFAULT_DIFF, getNotes());

		return {
			diffs: diffs,
			events: getEvents()
		}
	}
}
