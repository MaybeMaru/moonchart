package moonchart.backend;

import moonchart.formats.BasicFormat;
import moonchart.backend.FormatMacro;
import moonchart.backend.FormatData;
import moonchart.backend.Util;
import haxe.io.Path;

using StringTools;

@:keep // Should fix the DCE?
class FormatDetector
{
	public static var formatMap(get, null):Map<Format, FormatData> = [];
	private static var initialized(null, null):Bool = false;

	// Make sure all formats are loaded any time formatMap is called
	inline static function get_formatMap()
	{
		loadFormats();
		return formatMap;
	}

	private static function loadFormats():Void
	{
		if (initialized)
			return;

		initialized = true;

		// Load up all formats data
		for (format in FormatMacro.loadFormats())
			registerFormat(format);
	}

	/**
	 * Returns a list of the IDs of all the currently available formats.
	 */
	public static function getList():Array<Format>
	{
		var formatList:Array<Format> = Util.mapKeyArray(formatMap);
		formatList.sort((a, b) -> Util.sortString(a, b));
		return formatList;
	}

	/**
	 * Adds a format to the formatMap list.
	 * This should be done automatically to formats with a ``__getFormat`` static function.
	 * The macro is still a little fucky though so for extra custom formats you may need to call this on Main.
	 */
	public inline static function registerFormat(data:FormatData):Void
	{
		formatMap.set(data.ID, data);
	}

	/**
	 * Returns the format data from a format ID.
	 */
	public inline static function getFormatData(format:Format):FormatData
	{
		return formatMap.get(format);
	}

	/**
	 * Returns the format class from a format ID.
	 */
	public inline static function getFormatClass(format:Format):Class<BasicFormat<{}, {}>>
	{
		return getFormatData(format).handler;
	}

	/**
	 * Identifies and returns the closest format ID to an input of file paths.
	 * Still VERY experimental and may not be always accurate.
	 */
	public static function findFormat(inputFiles:OneOfArray<String>):Format
	{
		var possibleFormats:Array<String> = getList();
		var files:Array<String> = inputFiles.resolve();

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
			isFolder = Util.isFolder(files[0]);
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
