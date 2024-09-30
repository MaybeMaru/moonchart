package moonchart.parsers;

import moonchart.formats.StepMania;
import moonchart.parsers.BasicParser;
import moonchart.parsers._internal.MSDFile;

using StringTools;

typedef StepManiaFormat =
{
	TITLE:String,
	ARTIST:String,
	OFFSET:Float,
	BPMS:Array<StepManiaBPM>,
	NOTES:Map<String, StepManiaNotes>
}

typedef StepManiaNotes =
{
	var dance:StepManiaDance;
	var diff:String;
	var desc:String;
	var notes:Array<StepManiaMeasure>;
	var charter:String;
	var meter:Int;
	var radar:Array<Float>;
}

typedef StepManiaBPM =
{
	beat:Float,
	bpm:Float
}

typedef StepManiaStep = Array<StepManiaNote>;
typedef StepManiaMeasure = Array<StepManiaStep>;

enum abstract StepManiaDance(String) from String to String
{
	var SINGLE = "dance-single";
	var DOUBLE = "dance-double";
}

typedef StepManiaParser = BasicStepManiaParser<StepManiaFormat>;

enum abstract ParsingState(Int)
{
	var SONG_INFO; // Reading song tags from the file
	var MAP_INFO; // Reading step/map tags from the file (difficulty etc)
}

/**
 * @author Nebula_Zorua & MaybeMaru
 * Basic parser for StepMania and StepManiaShark to extend from
 */
class BasicStepManiaParser<T:StepManiaFormat> extends BasicParser<T>
{
	override function stringify(data:T):String
	{
		var sm:StringBuf = new StringBuf();

		for (title in sortedFields(data, ["TITLE", "ARTIST", "OFFSET", "BPMS", "NOTES"]))
		{
			switch (title)
			{
				case 'NOTES':
					for (diff => notes in data.NOTES)
					{
						stringifyNotes(sm, notes);
					}
				default:
					final value:Dynamic = Reflect.field(data, title);
					sm.add("#" + title + ":" + MSDFile.msdValue(value) + ";\n");
			}
		}

		return sm.toString();
	}

	// TODO: parse charter, meter and radar values
	function stringifyNotes(sm:StringBuf, notes:StepManiaNotes):Void
	{
		var header:String = "#NOTES:\n";
		header += "\t" + notes.dance + ":\n";
		header += "\t" + notes.charter + ":\n";
		header += "\t" + notes.diff + ":\n";
		header += "\t" + notes.meter + ":\n";
		header += "\t" + notes.radar.join(",") + ":\n";

		sm.add(header);
		stringifyMeasures(sm, notes.notes);
	}

	function stringifyMeasures(sm:StringBuf, measures:Array<StepManiaMeasure>):Void
	{
		final l:Int = measures.length;

		for (i in 0...l)
		{
			for (step in measures[i])
				sm.add(step.join("") + "\n");

			sm.add((i != l - 1) ? ",\n" : ";\n");
		}
	}

	function getEmpty():T
	{
		var format:StepManiaFormat = {
			TITLE: "Unknown",
			ARTIST: "Unknown",
			OFFSET: 0,
			BPMS: [],
			NOTES: []
		}

		return cast format;
	}

	var msdFile:MSDFile;
	var idx:Int;
	var parseState:ParsingState;

	function getDefaultMap():StepManiaNotes
	{
		return {
			desc: "",
			dance: StepManiaDance.SINGLE,
			diff: "Medium",
			notes: [],
			charter: "Unknown",
			meter: 1,
			radar: [0, 0, 0, 0, 0]
		};
	}

	override function parse(string:String):T
	{
		var formatted:T = getEmpty();

		msdFile = new MSDFile(string); // Bulk of the parser
		parseState = SONG_INFO;

		var currentMapData:StepManiaNotes = getDefaultMap();

		idx = 0;
		while (idx < msdFile.values.length)
		{
			final params:Array<String> = msdFile.values[idx];
			final title:String = params[0].toUpperCase();
			final value:String = params[1];

			switch (parseState)
			{
				case SONG_INFO:
					parseSong(title, value, formatted, currentMapData);
				case MAP_INFO:
					parseMap(title, value, formatted, currentMapData);
			}

			idx++;
		}

		msdFile = null;

		return formatted;
	}

	function parseMap(title:String, value:String, formatted:T, currentMapData:StepManiaNotes):Void
	{
		final params:Array<String> = msdFile.values[idx];
		currentMapData.dance = params[1].trim();
		currentMapData.charter = params[2].trim();
		currentMapData.diff = params[3].trim();
		currentMapData.meter = Std.parseInt(params[4].trim());
		currentMapData.radar = params[5].trim().split(",").map(Std.parseFloat);

		readNoteData(currentMapData, params[6]);
		formatted.NOTES.set(currentMapData.diff, currentMapData);
	}

	function parseSong(title:String, value:String, formatted:T, currentMapData:StepManiaNotes):Void
	{
		switch (title)
		{
			case 'NOTES':
				currentMapData = getDefaultMap();
				parseMap(title, value, formatted, currentMapData);
			case 'BPMS':
				var data = value.split(",");
				for (bpm_data in data)
				{
					var workable_data:Array<String> = bpm_data.trim().replace("\n", "").split("="); // beat=bpm
					if (workable_data.length == 0)
						continue;
					formatted.BPMS.push({
						beat: Std.parseFloat(workable_data[0]),
						bpm: Std.parseFloat(workable_data[1])
					});
				}
			default:
				if (Reflect.hasField(formatted, title))
					Reflect.setField(formatted, title, value);
		}
	}

	function readNoteData(mapData:StepManiaNotes, noteData:String)
	{
		var measures:Array<String> = noteData.split(",");
		for (data in measures)
		{
			var measure:StepManiaMeasure = [];
			var noteRows = data.split("\n");
			for (row in noteRows)
			{
				var step:StepManiaStep = row.replace("\n", "").trim().split("");
				if (step.length > 0)
					measure.push(step);
			}

			mapData.notes.push(measure);
		}
	}
}
