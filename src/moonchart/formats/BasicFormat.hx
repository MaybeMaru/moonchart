package moonchart.formats;

import moonchart.backend.Timing;
import moonchart.backend.Util;

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
	scrollSpeeds:Map<String, Float>,
	offset:Float,
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
	var LANES_LENGTH = "LANES_LENGTH"; // usually 4
	var AUDIO_FILE = "AUDIO_FILE";
	var SONG_ARTIST = "SONG_ARTIST";
	var SONG_CHARTER = "SONG_CHARTER";
}

typedef BasicFormatMetadata =
{
	timeFormat:TimeFormat,
	supportsDiffs:Bool, // If the format contains multiple diffs inside one file
	supportsEvents:Bool // If the format supports events
}

typedef FormatDifficulty = Null<OneOfArray<String>>;

typedef DiffNotesOutput =
{
	diffs:Array<String>,
	notes:Map<String, Array<BasicNote>>
}

@:autoBuild(moonchart.backend.FormatMacro.build())
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
			supportsDiffs: false,
			supportsEvents: true
		};
	}

	// TODO: There are some formats that require/accept more than one metadata file
	// Could maybe make it a OneOfArray?
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

	/**
	 * Loads the basic data from a format into this format.
	 * The difficulties you want to be imported can be set with ``diffs``, leave null to load all found diffs.
	 *
	 * Multiple formats can be also loaded at the same time if ``format`` is set as an array if you were to be
	 * converting a single-diff format to a multi-diff format (like FNF (Legacy) to FNF (V-Slice)).
	 */
	public function fromFormat(format:OneOfArray<BasicFormat<{}, {}>>, ?diffs:FormatDifficulty):Dynamic
	{
		var formats:Array<BasicFormat<{}, {}>> = format.resolve();
		var basics:Array<BasicChart> = [for (i in formats) i.toBasicFormat()];
		var first:BasicChart = basics[0];

		var formatDiffs:Map<String, Array<BasicNote>> = [];
		var formatSpeeds:Map<String, Float> = [];

		for (basic in basics)
		{
			for (diff => notes in basic.data.diffs)
				formatDiffs.set(diff, notes);

			for (diff => speed in basic.meta.scrollSpeeds)
				formatSpeeds.set(diff, speed);
		}

		var basic:BasicChart = {
			data: {
				diffs: formatDiffs,
				events: first.data.events
			},
			meta: {
				title: first.meta.title,
				bpmChanges: Timing.cleanBPMChanges(first.meta.bpmChanges),
				scrollSpeeds: formatSpeeds,
				offset: first.meta.offset,
				extraData: first.meta.extraData
			}
		}

		this.fromBasicFormat(basic, diffs);
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
	public inline function resolveDiffs(?diff:FormatDifficulty):Array<String>
	{
		var resolve = diff != null ? diff.resolve() : null;
		return (resolve != null && resolve.length > 0) ? resolve : [BasicFormat.DEFAULT_DIFF];
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
				var error:String = "Couldn't find difficulties " + chartDiff.resolve() + " on this chart.\n";
				error += (foundDiffs.length <= 0) ? "No other difficulties were found." : "Found other difficulties: " + foundDiffs;
				throw error;
			}
		}

		return {
			diffs: pushedDiffs,
			notes: chartNotes
		}
	}
}
