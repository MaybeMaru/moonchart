package moonchart.parsers;

import moonchart.parsers.BasicParser;

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
	Lane:Int,
	KeySounds:Array<String>
}

// Too lazy to use a yaml parser lol
class QuaverParser extends BasicParser<QuaverFormat>
{
	override function stringify(data:QuaverFormat):String
	{
		var result:StringBuf = new StringBuf();

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
			result.add(value is Array ? quaArray(value, field) : field + ": " + Std.string(value) + "\n");
		}

		return result.toString();
	}

	function resolveQua(value:Dynamic, name:String)
	{
		if (value is Array)
			return quaArray(value, name);

		return name + ": " + Std.string(value) + "\n";
	}

	function quaArray(data:Array<Dynamic>, name:String)
	{
		if (data.length <= 0)
		{
			return name + ": []\n";
		}

		var buf = new StringBuf();
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

		return buf.toString();
	}

	inline function quaArrayItem(name:String, value:Dynamic, start:Bool):String
	{
		return (start ? "- " : "  ") + name + ": " + Std.string(value) + "\n";
	}

	override function parse(string:String):QuaverFormat
	{
		var lines = splitLines(string);
		var data:QuaverFormat = {};

		final l = lines.length;
		var i = 0;

		while (i < l)
		{
			var line = lines[i++];
			var nextLine = lines[i];

			// Is Array
			if (i < l && nextLine.startsWith("-"))
			{
				var array:Array<Dynamic> = [];
				Reflect.setField(data, line.split(":")[0], array);

				var item:Dynamic = null;
				while (true)
				{
					// Finished the array
					if (i >= l || (!nextLine.startsWith("-") && !nextLine.startsWith(" ")))
					{
						array.push(item);
						break;
					}

					line = lines[i++];
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
					var content = line.substr(2, line.length).split(":");
					Reflect.setField(item, content[0], resolveBasic(content[1]));
				}
			}
			else
			{
				final content = line.split(":");
				final valueStr = content[1].substring(1, content[1].length);
				Reflect.setField(data, content[0], valueStr == "[]" ? [] : resolveBasic(content[1]));
			}
		}

		return data;
	}
}
