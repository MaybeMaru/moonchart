package moonchart.parsers;

import moonchart.parsers.BasicParser;
import moonchart.backend.Util;

using StringTools;

typedef QuaverFormat =
{
	?AudioFile:String,
	?BackgroundFile:String,
	?MapId:Int,
	?MapSetId:Int,
	?Mode:String,
	?Artist:String,
	?Source:String,
	?Tags:String,
	?Creator:String,
	?Description:String,
	?BPMDoesNotAffectScrollVelocity:Bool,
	?InitialScrollVelocity:Float,
	?EditorLayers:Array<Dynamic>,
	?CustomAudioSamples:Array<Dynamic>,
	?SoundEffects:Array<Dynamic>,
	?SliderVelocities:Array<Dynamic>,

	?Title:String,
	?TimingPoints:Array<QuaverTimingPoint>,
	?HitObjects:Array<QuaverHitObject>,
	?DifficultyName:String
}

typedef QuaverTimingPoint =
{
	StartTime:Int,
	Bpm:Float
}

typedef QuaverHitObject =
{
	StartTime:Int,
	?EndTime:Int,
	Lane:Int8,
	KeySounds:Array<String>
}

// Too lazy to use a yaml parser lol
class QuaverParser extends BasicParser<QuaverFormat>
{
	override function stringify(data:QuaverFormat):String
	{
		var buf:StringBuf = new StringBuf();

		var fields = sortedFields(data, [
			"AudioFile",
			"BackgroundFile",
			"MapId",
			"MapSetId",
			"Mode",
			"Title",
			"Artist",
			"Source",
			"Tags",
			"Creator",
			"DifficultyName",
			"Description",
			"BPMDoesNotAffectScrollVelocity",
			"InitialScrollVelocity",
			"EditorLayers",
			"CustomAudioSamples",
			"SoundEffects",
			"TimingPoints",
			"SliderVelocities",
			"HitObjects"
		]);

		for (field in fields)
		{
			var value:Dynamic = Reflect.field(data, field);
			if (value is Array)
			{
				quaArray(buf, value, field);
			}
			else
			{
				buf.add(field + ": " + Std.string(value));
				buf.addChar("\n".code);
			}
		}

		return buf.toString();
	}

	function quaArray(buf:StringBuf, data:Array<Dynamic>, name:String)
	{
		if (data.length <= 0)
		{
			buf.add(name + ": []\n");
			return;
		}

		buf.add(name + ":\n");

		for (item in data)
		{
			var first:Bool = true;

			for (field in Reflect.fields(item))
			{
				var value:Dynamic = Reflect.field(item, field);
				if (value == null)
					continue;

				buf.add(quaArrayItem(field, value, first));

				if (first)
					first = false;
			}
		}
	}

	inline function quaArrayItem(name:String, value:Dynamic, start:Bool):String
	{
		return (start ? "- " : "  ") + name + ": " + Std.string(value) + "\n";
	}

	override function parse(string:String):QuaverFormat
	{
		var lines = splitLines(string);
		var data:QuaverFormat = {};
		var emptyArray:Array<Dynamic> = []; // Avoid too many unused array instances

		final l = lines.length;
		var i = 0;

		while (i < l)
		{
			var line = lines[i++];
			var nextLine = lines[i];

			// Is Array
			if (i < l && nextLine.ltrim().startsWith("-"))
			{
				var array:Array<Dynamic> = [];
				Reflect.setField(data, line.split(":")[0], array);

				var item:Dynamic = null;
				while (true)
				{
					// Finished the array
					if (i >= l || (nextLine.ltrim().length == nextLine.length && !nextLine.contains("-")))
					{
						array.push(item);
						break;
					}

					line = lines[i++].ltrim();
					nextLine = lines[i];

					// Start new item
					if (line.startsWith("-"))
					{
						// Push the last item
						if (item != null)
							array.push(item);

						item = {};
					}

					// Set item data
					var content = line.replace("- ", "").split(":");
					Reflect.setField(item, content[0], resolveBasic(content[1]));
				}
			}
			else
			{
				final content = line.split(":");
				final yamlValue = content[1].ltrim();
				final value:Dynamic = yamlValue.startsWith("[]") ? emptyArray : resolveBasic(yamlValue);
				Reflect.setField(data, content[0], value);
			}
		}

		return data;
	}
}
