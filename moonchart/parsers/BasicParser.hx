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

	function resolveBasic(value:String):Dynamic
	{
		value = value.trim();

		// Is a number
		if (~/^-?\d+(\.\d+)?$/.match(value))
		{
			return value.contains(".") ? Std.parseFloat(value) : Std.parseInt(value);
		}

		// Is a string
		return value;
	}

	inline function splitLines(string:String):Array<String>
	{
		return string.replace("\uFEFF", "").split("\n").filter((i:String) -> return i.trim().length > 0);
	}
}
