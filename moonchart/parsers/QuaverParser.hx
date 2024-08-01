package moonchart.parsers;

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
		var result:String = "";

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
			result += (value is Array ? quaArray(value, field) : field + ": " + Std.string(value) + "\n");
		}

		return result;
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

		name += ":\n";

		for (item in data)
		{
			var fields = sortedFields(item, ["StartTime", "Lane", "EndTime", "Bpm", "KeySounds"]);

			// Skip null crap
			while (Reflect.field(item, fields[0]) == null)
				fields.shift();

			// Aight the whole item is null, fuck
			if (fields.length == 0)
				continue;

			// First item has the "- " thingy
			var first = fields.shift();
			name += quaArrayItem(first, Reflect.field(item, first), true);

			// Draw the rest of the crap
			for (field in fields)
			{
				name += quaArrayItem(field, Reflect.field(item, field), false);
			}
		}

		return name;
	}

	function quaArrayItem(name:String, value:Dynamic, start:Bool)
	{
		if (value == null)
			return "";

		var result = start ? "- " : "  ";
		result += name + ": " + Std.string(value) + "\n";
		return result;
	}

	override function parse(string:String):QuaverFormat
	{
		var lines = splitLines(string);
		var data:QuaverFormat = {};

		while (lines.length > 0)
		{
			var line = lines.shift();
			if (line == null)
				break;

			var nextLine = lines[0];

			// Is Array
			if (nextLine != null && nextLine.startsWith("-"))
			{
				var array:Array<Dynamic> = [];
				Reflect.setField(data, line.split(":")[0], array);

				var item:Dynamic = null;
				while (true)
				{
					if (nextLine.startsWith("-"))
					{
						// Push the last item
						if (item != null)
							array.push(item);

						item = {};
					}

					line = lines.shift();
					nextLine = lines[0];

					var content = line.substr(2, line.length).split(":");
					Reflect.setField(item, content[0], resolveBasic(content[1]));

					// Finished the array
					if (nextLine == null || (!nextLine.startsWith("-") && !nextLine.startsWith(" ")))
					{
						array.push(item);
						break;
					}
				}
			}
			else
			{
				var content = line.split(":");
				Reflect.setField(data, content[0], resolveBasic(content[1]));
			}
		}

		return data;
	}
}
