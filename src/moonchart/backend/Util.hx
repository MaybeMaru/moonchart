package moonchart.backend;

import moonchart.formats.BasicFormat.BasicEvent;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.io.Bytes;

// Mainly just missing util from when this was a flixel dependant project
class Util
{
	public static inline var version:String = "Moonchart 0.2.2";

	public static var readFolder:String->Array<String> = (folder:String) -> {
		#if sys
		return FileSystem.readDirectory(folder);
		#else
		return [];
		#end
	}

	public static var saveBytes:(String, Bytes) -> Void = (path:String, bytes:Bytes) -> {
		#if sys
		File.saveBytes(path, bytes);
		#end
	}

	public static var saveText:(String, String) -> Void = (path:String, text:String) -> {
		#if sys
		File.saveContent(path, text);
		#end
	}

	public static var getText:String->String = (path:String) -> {
		#if sys
		return File.getContent(path);
		#else
		return "";
		#end
	}

	public static inline function minInt(a:Int, b:Int):Int
	{
		return Std.int(Math.min(a, b));
	}

	public static inline function maxInt(a:Int, b:Int):Int
	{
		return Std.int(Math.max(a, b));
	}

	public static inline function sortString(a:String, b:String, isAscending:Bool = true):Int
	{
		final order:Int = (isAscending ? -1 : 1);
		var result:Int = 0;

		a = a.toUpperCase();
		b = b.toUpperCase();

		if (a < b)
		{
			result = order;
		}
		else if (a > b)
		{
			result = -order;
		}

		return result;
	}

	public static inline function sortValues(a:Float, b:Float, isAscending:Bool = true):Int
	{
		final order:Int = (isAscending ? -1 : 1);
		var result:Int = 0;

		if (a < b)
		{
			result = order;
		}
		else if (a > b)
		{
			result = -order;
		}

		return result;
	}

	public static function resolveEventValues(event:BasicEvent):Array<Dynamic>
	{
		var values:Array<Dynamic>;

		if (event.data.VALUE_1 != null) // FNF (Psych Engine)
		{
			values = [event.data.VALUE_1, event.data.VALUE_2];
		}
		else if (event.data.array != null)
		{
			values = event.data.array.copy();
		}
		else
		{
			var fields = Reflect.fields(event.data);
			fields.sort((a, b) -> return Util.sortString(a, b));
			values = [];

			for (field in fields)
			{
				values.push(Reflect.field(event.data, field));
			}
		}

		return values;
	}

	public static function mapKeyArray<T>(map:Map<T, Dynamic>):Array<T>
	{
		var array:Array<T> = [];
		for (key in map.keys())
			array.push(key);

		return array;
	}
}

abstract OneOfTwo<T1, T2>(Dynamic) from T1 from T2 to T1 to T2 {}
