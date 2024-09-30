package moonchart.backend;

import moonchart.formats.BasicFormat;

enum abstract FormatMeta(Int) from Int to Int
{
	var FALSE = 0;
	var TRUE = 1;
	var POSSIBLE = 2;
}

// Keeping for backwards compat, should prob at this with macros too
enum abstract Format(String) from String to String
{
	var FNF_LEGACY;
	var FNF_LEGACY_PSYCH;
	var FNF_LEGACY_FPS_PLUS;
	var FNF_KADE;
	var FNF_MARU;
	var FNF_CODENAME;
	var FNF_LUDUM_DARE;
	var FNF_VSLICE;
	var GUITAR_HERO;
	var OSU_MANIA;
	var QUAVER;
	var STEPMANIA;
	var STEPMANIA_SHARK;
	var MIDI;
}

typedef FormatData =
{
	ID:Format,
	name:String,
	description:String,
	extension:String,
	hasMetaFile:FormatMeta,
	?metaFileExtension:String,
	?packedExtension:String,
	?specialValues:Array<String>,
	?findMeta:Array<String>->String,
	handler:Class<DynamicFormat>
}
