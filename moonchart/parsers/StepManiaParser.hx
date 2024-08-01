package moonchart.parsers;

import haxe.ds.StringMap;
import moonchart.parsers.BasicParser;

using StringTools;

// TODO: stepmania has some extra fields that even if theyre empty are *needed* i guess
// prob should add em eventually for cleaner results + makin sure it works ingame
// (this applies to the rest of the formats too)
typedef StepManiaFormat =
{
	TITLE:String,
	OFFSET:Float,
	BPMS:Array<StepManiaBPM>,
	NOTES:Map<String, StepManiaNotes>
}

typedef StepManiaBPM =
{
	beat:Float,
	bpm:Float
}

typedef StepManiaStep = Array<String>;
typedef StepManiaMeasure = Array<StepManiaStep>;

enum abstract StepManiaDance(String) from String to String
{
	var SINGLE = "dance-single";
	var DOUBLE = "dance-double";
}

typedef StepManiaNotes =
{
	var dance:StepManiaDance;
	var diff:String;
	var notes:Array<StepManiaMeasure>;
}

typedef StepManiaFormatDirty =
{
	?TITLE:String,
	?OFFSET:Float,
	?BPMS:Array<String>,
	?NOTES:Array<String>
	// Im too lazy to make these their actual types lol
	// so it gets parsed first as a string and the dirty work gets done later
}

class StepManiaParser extends BasicParser<StepManiaFormat>
{
	override function stringify(data:StepManiaFormat):String
	{
		var result:String = "";

		var fields = sortedFields(data, ["TITLE", "OFFSET", "BPMS", "NOTES"]);

		for (field in fields)
		{
			var value:Dynamic = Reflect.field(data, field);

			if (value is StringMap)
			{
				result += smNotes(value);
			}
			else
			{
				result += "#" + field + ":" + smValue(value) + ";\n";
			}
		}

		return result;
	}

	function smValue(value:Dynamic)
	{
		var str:String = "";

		if (value is Array)
		{
			var array:Array<Dynamic> = value;
			for (i in 0...array.length)
			{
				str += smBasic(array[i]);
				str += "\n";
				if (i < array.length - 1)
				{
					str += ",";
				}
			}
		}
		else
		{
			str += smBasic(value);
		}

		return str;
	}

	function smBasic(value:Dynamic):String
	{
		// BPM Changes, some nice and sloppy unsafe code here for ya
		if (Reflect.hasField(value, "beat"))
		{
			return smBasic(Reflect.field(value, "beat")) + "=" + smBasic(Reflect.field(value, "bpm"));
		}

		if (value is Float || value is Int)
		{
			var num:Int = Std.int(value);
			var decimals:String = Std.string(Std.int((value - value) * 1000));
			while (decimals.length < 3)
			{
				decimals += "0";
			}

			return '$num.$decimals';
		}

		return Std.string(value);
	}

	function smNotes(charts:Map<String, StepManiaNotes>)
	{
		var str:String = "";

		for (diff => chart in charts)
		{
			str += "#NOTES:\n";
			str += "\t" + chart.dance + ":\n";
			str += "\t" + chart.diff + ":\n";
			str += "\t1:\n";
			str += "\t0,0,0,0,0:\n";

			for (m in 0...chart.notes.length)
			{
				for (step in chart.notes[m])
				{
					str += step.join("");
					str += "\n";
				}

				if (m < chart.notes.length - 1)
				{
					str += ",\n";
				}
			}

			str += ";\n";
		}

		return str;
	}

	override function parse(string:String):StepManiaFormat
	{
		var lines = splitLines(string);
		var sm:StepManiaFormatDirty = {};

		while (lines.length > 0)
		{
			var line = lines.shift().trim();
			if (line == null)
				break;

			if (line.startsWith("#"))
			{
				line = line.substring(1, line.length);

				var name:String = line.substring(0, line.indexOf(":"));

				if (line.endsWith(";") && !line.contains("=")) // Simple value
				{
					var stringValue = line.substring(name.length + 1, line.length - 1);
					var value:Dynamic = stringValue.length > 0 ? resolveBasic(stringValue) : "";
					Reflect.setField(sm, name, value);
				}
				else // Array value
				{
					// Arrays are a little tricky to parse since they dont contain basic data
					// Its more like hardcoded shit like maps and the notes values
					// So fuck it, gonna keep the contents of these as strings

					var arrayLines:Array<String> = Reflect.field(sm, name) ?? new Array<String>();

					// First array item can be next to the value name for some reason
					if (line.length - name.length > 1)
					{
						var items:Array<String> = line.substring(name.length + 1, line.length - 1).split(",");
						for (item in items)
						{
							arrayLines.push(item);
						}
					}

					var curLine:String = "";
					var indexData:String = "";

					// Get the contents to parse from the array
					while (true)
					{
						curLine = lines.shift();
						if (curLine == null || curLine.contains(";"))
							break;

						var comment = curLine.indexOf("//");
						if (comment != -1)
						{
							curLine = curLine.substring(0, comment);
						}

						if (curLine.startsWith(" ") || curLine.startsWith("\t"))
						{
							curLine = curLine.trim();
							arrayLines.push(curLine); // Doesnt remove the ":" suffix for later parsing btw!!
						}
						else
						{
							curLine = curLine.trim();

							if (curLine.startsWith(","))
							{
								var line = curLine.substring(1, curLine.length);
								if (line.length > 0)
								{
									indexData += line;
								}

								if (indexData.length > 0)
								{
									arrayLines.push(indexData);
									indexData = "";
								}
							}
							else
							{
								indexData += curLine;
							}
						}
					}

					Reflect.setField(sm, name, arrayLines);
				}
			}
		}

		// Time to get dirty

		var data:StepManiaFormat = {
			TITLE: sm.TITLE,
			OFFSET: sm.OFFSET,
			BPMS: [],
			NOTES: []
		}

		for (change in sm.BPMS)
		{
			var split = change.split("=");
			data.BPMS.push({
				beat: Std.parseFloat(split[0]),
				bpm: Std.parseFloat(split[1])
			});
		}

		var chart:StepManiaNotes = null;
		var danceLength:Int = 4;

		while (sm.NOTES.length > 0)
		{
			var item = sm.NOTES.shift();

			if (item.endsWith(":"))
			{
				if (chart != null)
				{
					data.NOTES.set(chart.diff, chart);
				}

				// Dont know what the others do yet
				var dance:StepManiaDance = (item.substring(0, item.length - 1));
				var b = sm.NOTES.shift();
				var diff = sm.NOTES.shift();
				var d = sm.NOTES.shift();
				var e = sm.NOTES.shift();

				chart = {
					dance: dance,
					diff: diff.substring(0, diff.length - 1),
					notes: []
				}

				danceLength = switch (dance)
				{
					case SINGLE: 4;
					case DOUBLE: 8;
					default: 4;
				}
			}
			else
			{
				var measure:StepManiaMeasure = [];

				var l = item.length;
				for (i in 0...l)
				{
					if (i % danceLength == 0)
					{
						measure.push(item.substr(i, danceLength).split(""));
					}
				}

				chart.notes.push(measure);
			}
		}

		// Chart only has one diff
		if (Lambda.count(data.NOTES) <= 0 && chart != null)
		{
			data.NOTES.set(chart.diff, chart);
		}

		return data;
	}
}
