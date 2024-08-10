package moonchart.formats;

import moonchart.backend.Util;
import moonchart.backend.Util.OneOfTwo;

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
	var SONG_ARTIST = "SONG_ARTIST";
	var SONG_CHARTER = "SONG_CHARTER";
}

typedef BasicFormatMetadata =
{
	timeFormat:TimeFormat,
	supportsEvents:Bool // TODO: double check later for all formats, im too ill to check rn
}

typedef FormatDifficulty = Null<OneOfTwo<String, Array<String>>>;

typedef DiffNotesOutput =
{
	diffs:Array<String>,
	notes:Map<String, Array<BasicNote>>
}

abstract class BasicFormat<D, M>
{
	public var data:D;
	public var meta:M;
	public var diffs(default, set):Array<String>;

	inline function set_diffs(diff:FormatDifficulty)
		return this.diffs = resolveDiffs(diff);

	public var formatMeta(default, null):BasicFormatMetadata;

	public function new(formatMeta:BasicFormatMetadata)
	{
		this.formatMeta = formatMeta ?? {
			timeFormat: MILLISECONDS,
			supportsEvents: true
		};
	}

	public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):BasicFormat<D, M>
	{
		throw "fromFile needs to be implemented in this format!";
		return null;
	}

	public function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):Dynamic
	{
		throw "fromBasicFormat needs to be implemented in this format!";
		return null;
	}

	public function fromFormat(format:BasicFormat<{}, {}>, ?diffs:FormatDifficulty):Dynamic
	{
		fromBasicFormat(format.toBasicFormat(), diffs);
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

	public function getNotes(?diff:String):Array<BasicNote>
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
		var chartDiffs = new BasicChartDiffs();

		for (diff in this.diffs)
		{
			chartDiffs.set(diff, getNotes(diff));
		}

		return {
			diffs: chartDiffs,
			events: getEvents()
		}
	}

	// Just for util
	public function resolveDiffs(?diff:FormatDifficulty):Array<String>
	{
		if (diff == null)
			return [BasicFormat.DEFAULT_DIFF];

		return diff is String ? [diff] : cast diff;
	}

	public function resolveDiffsNotes(chart:BasicChart, ?chartDiff:FormatDifficulty):DiffNotesOutput
	{
		final foundDiffs = Util.mapKeyArray(chart.data.diffs);
		this.diffs = chartDiff ?? foundDiffs;

		var pushedDiffs:Array<String> = [];
		var chartNotes:Map<String, Array<BasicNote>> = [];

		for (diff in diffs)
		{
			// Skip diffs not found
			if (!chart.data.diffs.exists(diff))
				continue;

			chartNotes.set(diff, chart.data.diffs.get(diff));
			pushedDiffs.push(diff);
		}

		if (pushedDiffs.length <= 0)
		{
			// Set diff to the default one if it exists (from a no multi-diffs format)
			if (chartDiff != null && foundDiffs[0] == DEFAULT_DIFF)
			{
				// Remove default data
				var defaultData = chart.data.diffs.get(DEFAULT_DIFF);
				chart.data.diffs.remove(DEFAULT_DIFF);

				// Set the default data to new found diff
				var foundDiff = resolveDiffs(chartDiff)[0];
				chart.data.diffs.set(foundDiff, defaultData);
				chartNotes.set(foundDiff, defaultData);
			}
			else
			{
				throw "No difficulty was found for this chart.";
			}
		}

		return {
			diffs: pushedDiffs,
			notes: chartNotes
		}
	}
}
