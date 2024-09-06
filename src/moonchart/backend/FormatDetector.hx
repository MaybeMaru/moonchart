package moonchart.backend;

import moonchart.backend.FormatMacro;
import moonchart.backend.Util;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class FormatDetector
{
	private static var formatMap(get, null):Map<String, FormatData> = [];
	private static var initialized:Bool = false;

	// Make sure all formats are loaded any time formatMap is called
	inline static function get_formatMap()
	{
		loadFormats();
		return formatMap;
	}

	public static function loadFormats():Void
	{
		if (initialized)
			return;

		initialized = true;

		// Load up all formats data
		for (format in FormatMacro.loadFormats())
			registerFormat(format);
	}

	public inline static function registerFormat(data:FormatData)
	{
		formatMap.set(data.ID, data);
	}

	public inline static function getFormatData(format:String):FormatData
	{
		return formatMap.get(format);
	}

	public static function findFormat(files:Array<String>):String
	{
		var possibleFormats:Array<String> = Util.mapKeyArray(formatMap);
		possibleFormats.sort((a, b) -> Util.sortString(a, b));

		var hasMeta:Bool = (files.length > 1);
		var isFolder:Bool;
		var fileExtension:String;

		if (hasMeta)
		{
			isFolder = false;
		}
		else
		{
			// Folder charts are forced to have meta
			isFolder = FileSystem.isDirectory(files[0]);
			hasMeta = isFolder;
		}

		fileExtension = (isFolder ? "" : Path.extension(files[0]));

		// Check based on simple data like extensions, folders, needs metadata, etc
		possibleFormats = possibleFormats.filter((format) ->
		{
			var data = getFormatData(format);

			// Setting up some format crap
			var forcedMeta:Bool = data.hasMetaFile == 1;
			var canHaveMeta:Bool = data.hasMetaFile == 2;
			var needsFolder:Bool = data.extension.startsWith("folder");
			var extension:String = needsFolder ? data.extension.split("::").pop() : data.extension;

			// Do the checks for matching formats
			var metaMatch = ((forcedMeta == hasMeta) || canHaveMeta);
			var folderMatch = (needsFolder == isFolder);
			var extensionMatch = isFolder ? true : (extension == fileExtension);

			// Finally, filter in or out matching formats
			return metaMatch && folderMatch && extensionMatch;
		});

		// Check if we got the format with the first filter
		if (possibleFormats.length <= 0)
		{
			throw "Format not found for file(s) " + files;
			return null;
		}
		else if (possibleFormats.length == 1)
		{
			return possibleFormats[0];
		}

		// If we didnt get it then we are close and gotta do some extra more indepth checks
		possibleFormats = possibleFormats.filter((format) ->
		{
			var data = getFormatData(format);
			var metaFile = data.findMeta != null ? data.findMeta(files) : files[0];
			var mainFile = files[((files.indexOf(metaFile) + 1) % files.length)];

			if (data.specialValues != null)
			{
				var mainContent = Util.getText(mainFile);
				for (value in data.specialValues)
				{
					if (!mainContent.contains(value))
						return false;
				}
			}

			return true;
		});

		// Fuck it we ball
		return possibleFormats[possibleFormats.length - 1];
	}
}
