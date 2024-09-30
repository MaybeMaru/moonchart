package moonchart.formats;

import moonchart.backend.FormatData;
import moonchart.backend.FormatDetector;
import haxe.io.Bytes;
import moonchart.backend.Timing;
import moonchart.backend.Util;

using StringTools;

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

enum abstract BasicNoteType(String) from String to String
{
	var DEFAULT = "";
	var ROLL;
	var MINE;
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
	var LANES_LENGTH; // usually 4 or 8
	// var STRUMLINES_LENGTH; TODO: add this metadata for better lane data control
	var AUDIO_FILE;
	var SONG_ARTIST;
	var SONG_CHARTER;
}

typedef BasicFormatMetadata =
{
	timeFormat:TimeFormat,
	supportsDiffs:Bool, // If the format contains multiple diffs inside one file
	supportsEvents:Bool, // If the format supports events
	?isBinary:Bool, // If the format files are binary (normally false)
	?supportsPacks:Bool // If the format supports zip packs
}

typedef FormatDifficulty = Null<OneOfArray<String>>;

typedef FormatStringify =
{
	data:String,
	?meta:String,
}

typedef FormatEncode =
{
	data:Bytes,
	?meta:Bytes,
}

typedef DiffNotesOutput =
{
	diffs:Array<String>,
	notes:Map<String, Array<BasicNote>>
}

typedef DynamicFormat = BasicFormat<{}, {}>;

@:keep
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
			supportsEvents: true,
		};

		this.formatMeta.isBinary ??= false;
		this.formatMeta.supportsPacks ??= false;
	}

	// TODO: There are some formats that require/accept more than one metadata file
	// Could maybe make it a OneOfArray?
	public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):BasicFormat<D, M>
	{
		throw "fromFile needs to be implemented in this format!";
		return null;
	}

	public function fromPack(path:String, diff:FormatDifficulty):BasicFormat<D, M>
	{
		if (formatMeta.supportsPacks)
			throw "fromPack needs to be implemented in this format!";

		return null;
	}

	public function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):BasicFormat<D, M>
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
	public function fromFormat(format:OneOfArray<DynamicFormat>, ?diffs:FormatDifficulty):BasicFormat<D, M>
	{
		var formats:Array<DynamicFormat> = format.resolve();
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

	public function stringify():FormatStringify
	{
		throw "stringify needs to be implemented in this format!";
		return null;
	}

	public function encode():FormatEncode
	{
		throw "encode needs to be implemented in this format!";
		return null;
	}

	public function save(path:String, ?metaPath:String):Void
	{
		final format:String = FormatDetector.getClassFormat(cast Type.getClass(this));
		final formatData:Null<FormatData> = (format.length > 0) ? FormatDetector.getFormatData(format) : null;

		// Automatically add the file extension (if missing)
		if (formatData != null)
		{
			path = Util.resolveExtension(path, formatData.extension);
			metaPath = Util.resolveExtension(metaPath, formatData.metaFileExtension);
		}

		if (formatMeta.isBinary)
		{
			final bytes = encode();
			Util.saveBytes(path, bytes.data);
			if (metaPath != null && bytes.meta != null)
				Util.saveBytes(metaPath, bytes.meta);
		}
		else
		{
			final string = stringify();
			Util.saveText(path, string.data);
			if (metaPath != null && string.meta != null)
				Util.saveText(metaPath, string.meta);
		}
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

	public static inline var DEFAULT_DIFF:String = "default_diff";

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
		var resolve = (diff != null) ? diff.resolve() : null;
		return (resolve != null && resolve.length > 0) ? resolve : [BasicFormat.DEFAULT_DIFF];
	}

	public function formatDiff(diff:String):String
	{
		if (!Settings.CASE_SENSITIVE_DIFFS)
			diff = diff.toLowerCase();

		if (!Settings.SPACE_SENSITIVE_DIFFS)
			diff = diff.replace(" ", "-");

		return diff;
	}

	public function resolveDiffsNotes(chart:BasicChart, ?chartDiff:FormatDifficulty):DiffNotesOutput
	{
		// Locate the available diffs
		final foundDiffs:Array<String> = Util.mapKeyArray(chart.data.diffs);
		diffs = chartDiff ?? foundDiffs;

		// Format the diffs with settings
		for (i => diff in diffs)
			diffs[i] = formatDiff(diff);

		// Find and push diffs
		var pushedDiffs:Array<String> = [];
		var chartNotes:Map<String, Array<BasicNote>> = [];

		for (diff => notes in chart.data.diffs)
		{
			diff = formatDiff(diff);
			if (diffs.contains(diff))
			{
				chartNotes.set(diff, notes);
				pushedDiffs.push(diff);
			}
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
				var error:String = "Couldn't find difficulties " + this.diffs + " on this chart.\n";
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
