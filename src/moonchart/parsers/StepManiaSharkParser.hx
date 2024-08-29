// @author Nebula_Zorua
// For the SSC format aka Spinal Shark Collective format
// The new (SM5+) format
// Could just extend or modify StepManiaParser but I think there's enough changes to the format to warrant a new one
// (Also I wanted to rewrite the parser since I'm not the HUGEST fan of the other SM Parser)
package moonchart.parsers;

import moonchart.parsers.StepManiaParser.StepManiaStep;
import moonchart.parsers.StepManiaParser.StepManiaMeasure;
import moonchart.parsers.StepManiaParser.StepManiaNotes;
import moonchart.formats.StepMania.StepManiaNote;
import haxe.ds.StringMap;
import moonchart.parsers.BasicParser;
import moonchart.parsers.StepManiaParser.StepManiaBPM;
import moonchart.parsers.StepManiaParser.StepManiaDance;
import moonchart.parsers.StepManiaParser.StepManiaFormat;

using StringTools;

typedef SSCStop =
{
	beat:Float,
	secs_duration:Float
}

typedef SSCDelay =
{
	beat:Float,
	secs_duration:Float
}

typedef SSCWarp =
{
	beat:Float, // stored as row in the format. Stored as beat here for simplicity
	beat_duration:Float // stored as row in the format. Stored as beat here for simplicity
}

typedef SSCLabel =
{
	beat:Float, // Stored as row in the format. Stored as beat here for simplicity
	label:String
}

typedef SSCFormat = StepManiaFormat &
{
	STOPS:Array<SSCStop>,
	DELAYS:Array<SSCDelay>,
	WARPS:Array<SSCWarp>,
	LABELS:Array<SSCLabel>
}

// This could likely be moved somewhere else as this can be used in the SM parser too

typedef MSDValues = Array<Array<String>>;

class MSDFIle
{
	public var values:MSDValues = [];

	public function new(fileContents:String)
	{
		parseContents(fileContents);
	}

	public function parseContents(content:String)
	{
		// Based on the MSD parser found in Stepmania. Could probably be rewritten to take advantage of Haxe systems and reduce complexity
		// but I want as accurate as possible reading
		var currentlyReadingValue:Bool = false;
		var currentValue:String = '';

		var strippedContent = "";
		var regex = ~/(\/\/).+/;

		// Strip comments
		for (data in content.split("\n"))
		{
			data = regex.replace(data, "").rtrim();
			strippedContent += data + "\n";
		}

		var data:Array<String> = strippedContent.split(""); // all of the characters in the file
		var len:Int = data.length;
		var idx = 0;

		while (idx < len)
		{
			var char = data[idx];
			if (currentlyReadingValue)
			{
				if (char == '#')
				{
					// Malformed MSD file that forgot to include a ; to end the last param
					// We can check if this is the first char on a new line, and if it IS then we can just end the value where it was.

					var jdx = currentValue.length - 1;
					var valueData:Array<String> = currentValue.split("");
					var isFirst:Bool = true;
					while (jdx > 0 && valueData[jdx] != '\r' && valueData[jdx] != '\n')
					{
						if (valueData[jdx].isSpace(0))
						{
							jdx--;
							continue;
						}
						isFirst = false;
						break;
					}

					// Not the first char on a new line so we just continue
					if (!isFirst)
					{
						currentValue += char;
						idx++;
						continue;
					}

					// this WAS the first char, so push the param
					values[values.length - 1].push(currentValue.trim());
					currentValue = '';
					currentlyReadingValue = false;
				}
			}

			if (!currentlyReadingValue && char == '#')
			{
				values.push([]); // New params!!
				currentlyReadingValue = true;
			}

			// Move the index into the file up by 1
			if (!currentlyReadingValue)
			{
				if (char == '\\')
					idx += 2;
				else
					idx++;

				continue; // And end since no value is being read. Doesn't FUCKIN MATTER WHATS HERE!!
			}

			if (char == ':' || char == ';')
			{
				values[values.length - 1].push(currentValue);
				currentValue = '';
			}

			if (char == '#' || char == ':' || char == ';')
			{
				if (char == ';')
					currentlyReadingValue = false;
				idx++;
				continue;
			}

			if (idx < len && data[idx] == '\\')
				idx++;

			if (idx < len)
			{
				currentValue = currentValue + data[idx];
				idx++;
			}
		}

		if (currentlyReadingValue)
			values[values.length - 1].push(currentValue);
	}
}

enum ParsingState
{
	SONG_INFO; // Reading song tags from the file
	MAP_INFO; // Reading step/map tags from the file (difficulty etc)
}

class StepManiaSharkParser extends BasicParser<SSCFormat>
{
	// TODO: merge with basic stepmania and add stringify
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

	override function parse(string:String):SSCFormat
	{
		var formatted:SSCFormat = {
			TITLE: "Unknown",
			ARTIST: "Unknown",
			OFFSET: 0,
			BPMS: [],
			STOPS: [],
			DELAYS: [],
			WARPS: [],
			LABELS: [],
			NOTES: [],
			EXTRA_PARAMS: [],
		}

		var msdFile:MSDFIle = new MSDFIle(string); // Bulk of the parser
		var parseState:ParsingState = ParsingState.SONG_INFO;

		var currentMapData:StepManiaNotes = {
			desc: "",
			dance: StepManiaDance.SINGLE,
			diff: "Medium",
			notes: []
		};

		for (idx in 0...msdFile.values.length)
		{
			var params:Array<String> = msdFile.values[idx];
			var title:String = params[0].toUpperCase();
			var value:String = params[1];
			switch (parseState)
			{
				case SONG_INFO:
					switch (title)
					{
						case 'NOTEDATA': // No longer reading song data! Start reading map data!!
							parseState = ParsingState.MAP_INFO;
							currentMapData = {
								desc: "",
								dance: StepManiaDance.SINGLE,
								diff: "Medium",
								notes: []
							};
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
						case 'WARPS':
							var data = value.split(",");
							for (warp_data in data)
							{
								var workable_data:Array<String> = warp_data.trim().replace("\n", "").split("="); // beat=duration
								if (workable_data.length == 0)
									continue;
								formatted.WARPS.push({
									beat: Std.parseFloat(workable_data[0]),
									beat_duration: Std.parseFloat(workable_data[1])
								});
							}
						case 'STOPS':
							var data = value.split(",");
							for (stops_data in data)
							{
								var workable_data:Array<String> = stops_data.trim().replace("\n", "").split("="); // beat=duration
								if (workable_data.length == 0)
									continue;
								formatted.STOPS.push({
									beat: Std.parseFloat(workable_data[0]),
									secs_duration: Std.parseFloat(workable_data[1])
								});
							}
						case 'DELAYS':
							var data = value.split(",");
							for (delay_data in data)
							{
								var workable_data:Array<String> = delay_data.trim().replace("\n", "").split("="); // beat=duration
								if (workable_data.length == 0)
									continue;
								formatted.DELAYS.push({
									beat: Std.parseFloat(workable_data[0]),
									secs_duration: Std.parseFloat(workable_data[1])
								});
							}
						case 'LABELS':
							var data = value.split(",");
							for (label_data in data)
							{
								var workable_data:Array<String> = label_data.trim().replace("\n", "").split("="); // beat=label
								if (workable_data.length == 0)
									continue;
								formatted.LABELS.push({
									beat: Std.parseFloat(workable_data[0]),
									label: workable_data[1]
								});
							}
						default:
							if (Reflect.hasField(formatted, title)) Reflect.setField(formatted, title, value); else formatted.EXTRA_PARAMS.set(title, value);
					}
				case MAP_INFO:
					switch (title)
					{
						case 'DIFFICULTY':
							currentMapData.diff = value;
						case 'STEPSTYPE':
							currentMapData.dance = value;
						case 'DESCRIPTION':
							currentMapData.desc = value;
						case 'NOTES' | 'NOTES2':
							parseState = SONG_INFO;
							readNoteData(currentMapData, value); // Load in note data!!
							formatted.NOTES.set(currentMapData.diff, currentMapData);
						default:
							// TODO: Store chart-based warps, stops, etc!!
					}
			}
		}
		return formatted;
	}
}
