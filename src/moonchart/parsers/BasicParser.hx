package moonchart.parsers;

using StringTools;

class BasicParser<T>
{
	public function new() {}

	public function stringify(data:T):String
	{
		throw "stringify needs to be implemented in this parser!";
		return null;
	}

	public function parse(string:String):T
	{
		throw "parse needs to be implemented in this parser!";
		return null;
	}

	// TODO: implement for better results in osu, quaver and sm parsers
	function sortedFields(input:Dynamic, sort:Array<Dynamic>):Array<String>
	{
		var fields = Reflect.fields(input);
		var result:Array<String> = [];

		// Add items based on sort
		for (i in sort)
		{
			if (fields.contains(i))
			{
				result.push(i);
				fields.remove(i);
			}
		}

		// Add any missed items not included in the sort
		for (i in fields)
		{
			result.push(i);
		}

		return result;
	}

	// static final numberRegex = ~/^-?\d+(\.\d+)?$/;

	function resolveBasic(value:String):Dynamic
	{
		value = value.trim();
		var numValue = Std.parseFloat(value);

		// Is a number
		if (!Math.isNaN(numValue))
			return numValue;

		// Is a string
		return value;
	}

	function splitLines(string:String):Array<String>
	{
		final arr:Array<String> = [];

		for (line in string.split("\n"))
		{
			// BOM fix
			if (line.charCodeAt(0) == 0xFEFF)
				line = line.substr(1);

			if (line.trim().length > 0)
				arr.push(line);
		}

		return arr;
	}
}
