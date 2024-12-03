package moonchart.backend;

import haxe.io.Bytes;
import haxe.io.Path;
import moonchart.formats.BasicFormat.BasicEvent;

using StringTools;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if openfl
import openfl.utils.Assets;
#end
#if cpp
import cpp.NativeArray;
#end

// Mainly just missing util from when this was a flixel dependant project
class Util
{
	public static inline var version:String = "Moonchart 0.4.0";

	public static var readFolder:String->Array<String> = (folder:String) -> {
		#if sys
		return FileSystem.readDirectory(folder);
		#else
		return [];
		#end
	}

	public static var isFolder:String->Bool = (folder:String) -> {
		#if sys
		return FileSystem.isDirectory(folder);
		#else
		return false;
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

	public static var getBytes:String->Bytes = (path:String) -> {
		#if sys
		return File.getBytes(path);
		#elseif openfl
		return Assets.getBytes(path);
		#else
		return null;
		#end
	}

	public static var getText:String->String = (path:String) -> {
		#if sys
		return File.getContent(path);
		#elseif openfl
		return Assets.getText(path);
		#else
		return "";
		#end
	}

	public static function resolveFolder(path:String):String
	{
		path = path.trim();

		if (path.endsWith("/"))
			path = path.substr(0, path.length - 1);

		return path;
	}

	public static function resolveExtension(?path:String, extension:String):Null<String>
	{
		if (path == null)
			return path;

		var ext = '.$extension';
		if (Path.extension(path).length <= 0)
			path += ext;

		return path;
	}

	public static function extendPath(?path:String, ?extension:String):Null<String>
	{
		if (path == null)
			return path;

		if (!path.endsWith("/"))
			path += "/";

		if (extension != null)
			path += extension;

		return path;
	}

	public static inline function minInt(a:Int, b:Int):Int
	{
		return Std.int(Math.min(a, b));
	}

	public static inline function maxInt(a:Int, b:Int):Int
	{
		return Std.int(Math.max(a, b));
	}

	public static function customSort(array:Array<String>, sort:Array<String>)
	{
		var result:Array<String> = [];

		// Add items based on sort
		for (i in sort)
		{
			if (array.contains(i))
			{
				result.push(i);
				array.remove(i);
			}
		}

		// Add any missed items not included in the sort
		for (i in array)
			result.push(i);

		return result;
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

	public static function makeArrayEvent(time:Float, name:String, array:Array<Dynamic>):BasicEvent
	{
		return {
			time: time,
			name: name,
			data: {
				array: array
			}
		}
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
			var fields:Array<String> = Reflect.fields(event.data);
			values = [];

			if (fields.length > 0)
			{
				fields.sort((a, b) -> return Util.sortString(a, b));

				for (field in fields)
					values.push(Reflect.field(event.data, field));
			}
		}

		return values;
	}

	public static inline function resizeArray<T>(array:Array<T>, size:Int):Void
	{
		#if cpp
		NativeArray.setSize(array, size);
		#else
		array.resize(size);
		#end
	}

	public static inline function makeArray<T>(size:Int):Array<T>
	{
		#if cpp
		return NativeArray.create(size);
		#else
		var array:Array<T> = [];
		array.resize(size);
		return array;
		#end
	}

	public static inline function setArray<T>(array:Array<T>, index:Int, value:T):Void
	{
		#if cpp
		NativeArray.unsafeSet(array, index, value);
		#else
		array[index] = value;
		#end
	}

	public static inline function getArray<T>(array:Array<T>, index:Int):T
	{
		#if cpp
		return NativeArray.unsafeGet(array, index);
		#else
		return array[index];
		#end
	}

	public static function fillMap<T>(keys:Array<String>, value:T):Map<String, T>
	{
		var map:Map<String, T> = [];
		for (key in keys)
			map.set(key, value);
		return map;
	}

	public static function mapKeyArray<K, T>(map:Map<K, T>):Array<K>
	{
		var array:Array<K> = [];
		for (key in map.keys())
			array.push(key);
		return array;
	}

	public static function mapFirst<K, T>(map:Map<K, T>):Null<T>
	{
		var iterator = map.iterator();
		return iterator.hasNext() ? iterator.next() : null;
	}

	public static function mapFirstKey<K, T>(map:Map<K, T>):Null<K>
	{
		var iterator = map.keys();
		return iterator.hasNext() ? iterator.next() : null;
	}

	// Safely check if 2 floats are equal with 2 decimal accuracy
	public static function equalFloat(a:Float, b:Float):Bool
	{
		return (Std.int(a * 100) == Std.int(b * 100));
	}
}

typedef Int8 = #if cpp cpp.UInt8; #else Int; #end
typedef StringInput = OneOfArray<String>;
typedef ChartSave = OneOfTwo<String, Bytes>;
abstract OneOfTwo<T1, T2>(Dynamic) from T1 from T2 to T1 to T2 {}

abstract JsonMap<T>(Dynamic) from Dynamic to Dynamic
{
	public function resolve():Map<String, T>
	{
		var map = new Map<String, T>();
		for (key in keys())
			map.set(key, get(key));

		return map;
	}

	public function fromMap(?map:Map<String, T>):JsonMap<T>
	{
		if (map != null)
		{
			for (key => value in map)
				set(key, value);
		}

		return this;
	}

	public inline function keys():Array<String>
	{
		return Reflect.fields(this);
	}

	public inline function get(key:String):T
	{
		return Reflect.field(this, key);
	}

	public inline function set(key:String, value:T):Void
	{
		Reflect.setField(this, key, value);
	}
}

abstract OneOfArray<T>(Dynamic) from T from Array<T> to T to Array<T>
{
	public inline function resolve():Array<T>
	{
		return ((this is Array) ? this : [this]);
	}
}
