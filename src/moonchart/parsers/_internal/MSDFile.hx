package moonchart.parsers._internal;

using StringTools;

typedef MSDValues = Array<Array<String>>;

/**
 * @author Nebula_Zorua
 * Based on the MSD parser found in Stepmania.
 * Could probably be rewritten to take advantage of Haxe systems and reduce complexity
 * but I want as accurate as possible reading
 */
class MSDFile
{
	public var values:MSDValues = [];

	public function new(fileContents:String)
	{
		parseContents(fileContents);
	}

	public function parseContents(content:String)
	{
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

	public static function msdValue(value:Dynamic)
	{
		var str:String = "";

		if (value is Array)
		{
			var array:Array<Dynamic> = value;
			for (i in 0...array.length)
			{
				str += msdBasic(array[i]);
				str += "\n";
				if (i < array.length - 1)
				{
					str += ",";
				}
			}
		}
		else
		{
			str += msdBasic(value);
		}

		return str;
	}

	public static function msdBasic(value:Dynamic):String
	{
		// BPM Changes, some nice and sloppy unsafe code here for ya
		if (Reflect.hasField(value, "beat"))
		{
			return msdBasic(Reflect.field(value, "beat")) + "=" + msdBasic(Reflect.field(value, "bpm"));
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
}
