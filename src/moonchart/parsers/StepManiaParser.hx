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
	// TODO:
	override function stringify(data:T):String
	{
		var sm:String = "";

		for (title in sortedFields(data, ["TITLE", "ARTIST", "OFFSET", "BPMS","NOTES"]))
		{
			var value:Dynamic = Reflect.field(data, title);
			switch (title)
			{
				case 'NOTES':
					for (diff => notes in data.NOTES)
					{
						sm += stringifyNotes(notes);
					}
				default:
					sm += "#" + title + ":" + MSDFile.msdValue(value) + ";\n";
			}
		}

		return sm;
	}

	// TODO: parse charter, meter and radar values
	function stringifyNotes(notes:StepManiaNotes):String
	{
		var sm:String = "#NOTES:\n";

		sm += "\t" + notes.dance + ":\n";
		sm += "\t" + notes.charter + ":\n";
		sm += "\t" + notes.diff + ":\n";
		sm += "\t" + notes.meter + ":\n";
		sm += "\t" + notes.radar.join(",") +":\n";

		sm += stringifyMeasures(notes.notes);

		return sm;
	}

	function stringifyMeasures(measures:Array<StepManiaMeasure>):String
	{
		final l:Int = measures.length;
		var sm:String = "";

		for (i in 0...l)
		{
			for (step in measures[i])
				sm += step.join("") + "\n";

			sm += (i != l - 1) ? ",\n" : ";\n";
		}

		return sm;
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

	function getDefaultMap():StepManiaNotes {
		return {
			desc: "",
			dance: StepManiaDance.SINGLE,
			diff: "Medium",
			notes: [],
			charter: "Unknown",
			meter: 1,
			radar: [0,0,0,0,0]
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
