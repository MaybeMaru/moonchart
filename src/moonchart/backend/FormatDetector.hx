package moonchart.backend;

import moonchart.backend.Util;
import moonchart.formats.*;
import moonchart.formats.fnf.*;
import moonchart.formats.fnf.legacy.*;
import haxe.EnumTools;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

// TODO: rework this to add some way to easily add new formats remotely when this becomes a haxelib
// Maybe using a macro instead?
enum Format
{
	FNF_LEGACY;
	FNF_LEGACY_PSYCH;
	FNF_LEGACY_FPS_PLUS;
	FNF_MARU;
	FNF_LUDUM_DARE;
	FNF_VSLICE;

	GUITAR_HERO;
	OSU_MANIA;
	QUAVER;
	STEPMANIA;
}

typedef FormatData =
{
	name:String,
	description:String,
	extension:String,
	hasMetaFile:Int, // 0 (no meta) 1 (needs meta) 2 (can have meta)
	?metaFileExtension:String,
	?specialValues:Array<String>,
	?findMeta:Array<String>->String,
	handler:Class<BasicFormat<{}, {}>>
}

class FormatDetector
{
	// TODO: add missing descriptions
	private static final formatMap:Map<Format, FormatData> = [
		FNF_LEGACY => {
			name: "FNF (Legacy)",
			description: "",
			extension: "json",
			hasMetaFile: 0,
			handler: FNFLegacy
		},
		FNF_LEGACY_PSYCH => {
			name: "FNF (Psych Engine)",
			description: "",
			extension: "json",
			hasMetaFile: 2,
			metaFileExtension: "json",
			specialValues: ['"gfSection":', '"stage":'], // '"splashSkin":'
			handler: FNFPsych
		},
		FNF_LEGACY_FPS_PLUS => {
			name: "FNF (FPS +)",
			description: "",
			extension: "json",
			hasMetaFile: 2,
			metaFileExtension: "json",
			specialValues: ['"gf":'],
			findMeta: (files) ->
			{
				for (file in files)
				{
					if (Util.getText(file).contains("events"))
						return file;
				}
				return files[0];
			},
			handler: FNFFpsPlus
		},
		FNF_MARU => {
			name: "FNF (Maru)",
			description: "",
			extension: "json",
			hasMetaFile: 2,
			metaFileExtension: "json",
			specialValues: ['"offsets":', '"players":'],
			handler: FNFMaru
		},
		FNF_LUDUM_DARE => {
			name: "FNF (Ludum Dare)",
			description: "This was a mistake.",
			extension: "folder::png",
			hasMetaFile: 1,
			metaFileExtension: "json",
			handler: FNFLudumDare
		},
		FNF_VSLICE => {
			name: "FNF (V-Slice)",
			description: "",
			extension: "json",
			hasMetaFile: 1,
			metaFileExtension: "json",
			specialValues: ['"scrollSpeed":', '"version":'],
			findMeta: (files) ->
			{
				for (file in files)
				{
					if (Util.getText(file).contains('"playData":'))
						return file;
				}
				return files[0];
			},
			handler: FNFVSlice
		},
		GUITAR_HERO => {
			name: "Guitar Hero",
			description: "",
			extension: "chart",
			hasMetaFile: 0,
			handler: GuitarHero
		},
		OSU_MANIA => {
			name: "Osu! Mania",
			description: "",
			extension: "osu",
			hasMetaFile: 0,
			handler: OsuMania
		},
		QUAVER => {
			name: "Quaver",
			description: "",
			extension: "qua",
			hasMetaFile: 0,
			handler: Quaver
		},
		STEPMANIA => {
			name: "StepMania",
			description: "",
			extension: "sm",
			hasMetaFile: 0,
			handler: StepMania
		}
	];

	public inline static function getFormatData(format:Format):FormatData
	{
		return formatMap.get(format);
	}

	public static function findFormat(files:Array<String>):Format
	{
		var possibleFormats:Array<Format> = EnumTools.createAll(Format);

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
