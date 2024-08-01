package moonchart.backend;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

// Mainly just missing util from when this was a flixel dependant project
class Util
{
    // TODO: add customization for other stuff like readDirectory

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