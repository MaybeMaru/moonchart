package moonchart.parsers;

using StringTools;

typedef GuitarHeroTimedObject =
{
	tick:Int,
	type:GuitarHeroTrackEvent,
	values:Array<Dynamic>
}

typedef GuitarHeroFormat =
{
	?Song:GuitarHeroSong,
	?SyncTrack:Array<GuitarHeroTimedObject>,
	?Events:Array<GuitarHeroTimedObject>,
	?ExpertSingle:Array<GuitarHeroTimedObject>
}

typedef GuitarHeroSong =
{
	Name:String,
	Resolution:Int,
	Offset:Float
}

enum abstract GuitarHeroTrackEvent(String) from String to String
{
	var TEMPO_ANCHOR = "A";
	var TEMPO_CHANGE = "B";
	var TEXT_EVENT = "E";
	var LEGACY_HAND = "H";
	var NOTE_EVENT = "N";
	var SPECIAL_PHRASE = "S";
	var TIME_SIGNATURE_CHANGE = "TS";
}

class GuitarHeroParser extends BasicParser<GuitarHeroFormat>
{
	public override function stringify(data:GuitarHeroFormat):String
	{
		var result:String = "";

		var headers = sortedFields(data, ["Song", "SyncTrack", "Events", "ExpertSingle"]);

		for (header in headers)
		{
			var headerData = Reflect.field(data, header);
			var headerResult:String = "";

			if (headerData is Array)
			{
				var array:Array<GuitarHeroTimedObject> = cast headerData;
				for (i in array)
				{
					var tick = Std.string(i.tick);
					var type = i.type;
					var values = i.values.join(" ");

					headerResult += '  $tick = $type $values\n';
				}
			}
			else
			{
				for (field in Reflect.fields(headerData))
				{
					var fieldData = Reflect.field(headerData, field);
					headerResult += '  $field = ' + ghField(fieldData) + '\n';
				}
			}

			result += '[$header]\n';
			result += '{\n';
			result += headerResult;
			result += '}\n';
		}

		return result;
	}

	function ghField(field:Dynamic):String
	{
		var str = Std.string(field);
		if (field is String)
		{
			str = '"$str"';
		}
		return str;
	}

	public override function parse(string:String):GuitarHeroFormat
	{
		var lines = splitLines(string);

		var data:GuitarHeroFormat = {}

		var headers:Map<String, Array<String>> = [];

		while (lines.length > 0)
		{
			var line = lines.shift().trim();

			if (line.endsWith("]"))
			{
				var header:String = line.substring(1, line.length - 1);
				var headerLines:Array<String> = [];
				headers.set(header, headerLines);

				var headerLine = lines.shift();
				while (true)
				{
					headerLine = lines.shift();
					if (headerLine.contains("}"))
						break;

					headerLines.push(headerLine.trim());
				}
			}
		}

		// Push crap
		for (header => lines in headers)
		{
			Reflect.setField(data, header, switch (header)
			{
				case "Song": resolveValuesGH(header, lines);
				default: resolveTrackEventsGH(header, lines);
			});
		}

		return data;
	}

	function resolveTrackEventsGH(field:String, lines:Array<String>):Array<GuitarHeroTimedObject>
	{
		var timedObjects:Array<GuitarHeroTimedObject> = [];

		for (line in lines)
		{
			var values = line.split("=");
			var typeData = values[1].trim().split(" ");

			var tick:Int = Std.parseInt(values[0].trim());
			var type:String = typeData.shift().trim();
			var other:Array<Dynamic> = [];

			while (typeData.length > 0)
				other.push(resolveBasic(typeData.shift().trim()));

			timedObjects.push({
				tick: tick,
				type: type,
				values: other
			});
		}

		return timedObjects;
	}

	function resolveValuesGH(field:String, lines:Array<String>):Dynamic
	{
		var gh:Dynamic = {};
		for (line in lines)
		{
			var values = line.split("=");
			var field = values[0].trim();
			var value = values[1].trim().replace('"', '');

			Reflect.setField(gh, field, resolveBasic(value));
		}
		return gh;
	}
}
