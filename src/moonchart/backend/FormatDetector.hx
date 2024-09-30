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
	public inline static function getFormatClass(format:Format):Class<DynamicFormat>
	{
		return getFormatData(format).handler;
	}

	/**
	 * Returns a new format instance from a format ID.
	 */
	public inline static function createFormatInstance(format:Format):DynamicFormat
	{
		return Type.createInstance(getFormatClass(format), []);
	}

	/**
	 * Returns the format ID from a format class.
	 */
	public static function getClassFormat(input:Class<DynamicFormat>):Format
	{
		for (format => data in formatMap)
		{
			if (data.handler == input)
				return format;
		}

		// throw 'Registered format not found for class $input.';
		return "";
	}

	/**
	 * Identifies and returns the instance of a format from an input of file paths.
	 * Still VERY experimental and may not be always accurate.
	 */
	public static function instanceFromFiles(inputFiles:OneOfArray<String>, ?diff:FormatDifficulty):DynamicFormat
	{
		var format:Format = findFormat(inputFiles);
		var instance:DynamicFormat = createFormatInstance(format);

		var files:Array<String> = inputFiles.resolve();
		return instance.fromFile(files[0], files[1], diff);
	}

	/**
	 * Identifies and returns the closest format ID from an input of file paths.
	 * Still VERY experimental and may not be always accurate.
	 */
	public static function findFormat(inputFiles:OneOfArray<String>):Format
	{
		final files:Array<String> = inputFiles.resolve();
		var possibleFormats:Array<String> = getList();

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
			final data = getFormatData(format);

			// Setting up some format crap
			final forcedMeta:Bool = (data.hasMetaFile == TRUE);
			final possibleMeta:Bool = (data.hasMetaFile == POSSIBLE);
			final needsFolder:Bool = data.extension.startsWith("folder");
			final extension:String = needsFolder ? data.extension.split("::").pop() : data.extension;

			// Do the checks for matching formats
			final metaMatch = ((forcedMeta == hasMeta) || possibleMeta);
			final folderMatch = (needsFolder == isFolder);
			final extensionMatch = isFolder ? true : (extension == fileExtension);

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
			final data = getFormatData(format);
			final metaFile = data.findMeta != null ? data.findMeta(files) : files[0];
			final mainFile = files[((files.indexOf(metaFile) + 1) % files.length)];

			if (data.specialValues != null)
			{
				final mainContent = Util.getText(mainFile);
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
