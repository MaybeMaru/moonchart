package moonchart.backend;

import moonchart.formats.BasicFormat;

enum abstract FormatMeta(Int) from Int to Int
{
	var FALSE = 0;
	var TRUE = 1;
	var POSSIBLE = 2;
}

typedef FormatData =
{
	ID:String,
	name:String,
	description:String,
	extension:String,
	hasMetaFile:FormatMeta,
	?metaFileExtension:String,
	?specialValues:Array<String>,
	?findMeta:Array<String>->String,
	handler:Class<BasicFormat<{}, {}>>
}
