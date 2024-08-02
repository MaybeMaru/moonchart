package moonchart.backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
import haxe.io.Bytes;

// Mainly just missing util from when this was a flixel dependant project
class Util
{
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
}
