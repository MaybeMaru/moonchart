package moonchart.parsers;

import moonchart.parsers.BasicParser;

using StringTools;

// Dumb hashlink fix
typedef OsuFormat =
{
	?format:String,
	?General:OsuGeneral,
	?Editor:OsuEditor,
	?Metadata:OsuMetadata,
	?Difficulty:OsuDifficulty,
	?Events:Array<Array<Dynamic>>,
	?TimingPoints:Array<Array<Float>>,
	?HitObjects:Array<Array<Int>>,
}

typedef OsuGeneral =
{
	AudioFilename:String,
	AudioLeadIn:Int,
	PreviewTime:Int,
	Countdown:Int,
	SampleSet:String,
	StackLeniency:Float,
	Mode:Int,
	LetterboxInBreaks:Int,
	SpecialStyle:Int,
	WidescreenStoryboard:Int
}

typedef OsuEditor =
{
	Bookmarks:Array<Int>,
	DistanceSpacing:Float,
	BeatDivisor:Int,
	GridSize:Int,
	TimelineZoom:Float
}

typedef OsuMetadata =
{
	Title:String,
	TitleUnicode:String,
	Artist:String,
	ArtistUnicode:String,
	Creator:String,
	Version:String,
	Source:String,
	BeatmapID:Int,
	BeatmapSetID:Int
}

typedef OsuDifficulty =
{
	HPDrainRate:Int,
	CircleSize:Int,
	OverallDifficulty:Int,
	ApproachRate:Int,
	SliderMultiplier:Float,
	SliderTickRate:Int,
}

class OsuParser extends BasicParser<OsuFormat>
{
	public override function stringify(data:OsuFormat):String
	{
		var result:String = data.format;

		var headers = [
			"General",
			"Editor",
			"Metadata",
			"Difficulty",
			"Events",
			"TimingPoints",
			"HitObjects"
		];

		for (header in headers)
		{
			result += '\n[$header]\n';

			var headerData = Reflect.field(data, header);
			if (headerData is Array)
			{
				result += (stringOsuVar(headerData, '\n') + '\n');
			}
			else
			{
				for (field in Reflect.fields(headerData))
				{
					result += '$field: ${stringOsuVar(Reflect.field(headerData, field))}\n';
				}
			}
		}

		return result;
	}

	static function stringOsuVar(value:Dynamic, arraySeparator:String = ","):String
	{
		if (value is Array)
		{
			var result = "";
			var array:Array<Dynamic> = value;
			for (i in 0...array.length)
			{
				result += stringOsuVar(array[i]);
				if (i < array.length - 1)
					result += arraySeparator;
			}
			return result;
		}

		return Std.string(value);
	}

	public override function parse(string:String):OsuFormat
	{
		var lines = splitLines(string);

		var data:OsuFormat = {};
		data.format = lines.shift(); // First line is always the osu chart format version

		while (lines.length > 0)
		{
			var line = lines.shift();
			if (line == null)
				break;

			// Found osu variable header
			if (line.startsWith("["))
			{
				// Setting up the variable
				var header = line.substr(1, line.length - 3);
				var headerData:Dynamic;

				// Fuck shit ass fuck
				if (header == "General" || header == "Editor" || header == "Metadata" || header == "Difficulty")
				{
					headerData = {};
					Reflect.setField(data, header, headerData);

					while (lines[0] != null && !lines[0].startsWith("["))
					{
						var content = lines.shift().split(":");
						var variable = content[0];
						Reflect.setField(headerData, variable, resolveBasic(content[1]));
					}
				}
				else
				{
					headerData = [];
					Reflect.setField(data, header, headerData);

					while (lines[0] != null && !lines[0].startsWith("["))
					{
						var line = lines.shift();
						if (line.startsWith("//"))
							continue;

						cast(headerData, Array<Dynamic>).push(resolveBasic(line.split(":")[0]));
					}
				}
			}
		}

		return data;
	}

	override function resolveBasic(value:String):Dynamic
	{
		// Is an array
		if (value.contains(","))
		{
			var array:Array<Dynamic> = [];
			for (i in value.split(","))
				array.push(resolveBasic(i));

			return array;
		}

		return super.resolveBasic(value);
	}
}
