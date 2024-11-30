package moonchart.formats.fnf;

import haxe.io.Path;
import moonchart.backend.FormatData;
import moonchart.backend.Optimizer;
import moonchart.backend.Timing;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;

// Chart
typedef FNFImaginativeNote = {
	var id:Int;
	var length:Float;
	var time:Float;
	var ?characters:Array<String>;
	var type:String;
}

typedef FNFImaginativeArrowField = {
	var tag:String;
	var characters:Array<String>;
	var notes:Array<FNFImaginativeNote>;
}

typedef FNFImaginativeCharacter = {
	var tag:String;
	var name:String;
	var position:String;
}

typedef FNFImaginativeFieldSettings = {
	var ?cameraTarget:String;
	var order:Array<String>;
	var enemy:String;
	var player:String;
}

typedef FNFImaginativeEvent = {
	var name:String;
	var params:Array<Dynamic>;
	var time:Float;
	var ?sub:Int;
}

typedef FNFImaginativeChart = {
	var speed:Float;
	var stage:String;
	var fields:Array<FNFImaginativeArrowField>;
	var characters:Array<FNFImaginativeCharacter>;
	var fieldSettings:FNFImaginativeFieldSettings;
	var ?events:Array<FNFImaginativeEvent>;
}

// Meta
typedef FNFImaginativeCheckpoint = { // used for bpm changes
	var time:Float;
	var bpm:Float;
	var signature:Array<Int>;
}

typedef FNFImaginativeAllowedModes = {
	var playAsEnemy:Bool;
	var p2AsEnemy:Bool;
}

typedef FNFImaginativeAudioMeta = {
	var artist:String;
	var name:String;
	var bpm:Float;
	var signature:Array<Int>;
	var ?offset:Float;
	var checkpoints:Array<FNFImaginativeCheckpoint>;
}

typedef FNFImaginativeSongMeta = {
	var name:String;
	var folder:String;
	var icon:String;
	var startingDiff:Int;
	var difficulties:Array<String>;
	var variants:Array<String>;
	var ?color:FlxColor;
	var allowedModes:FNFImaginativeAllowedModes;
}

class FNFImaginative extends BasicJsonFormat<FNFImaginativeChart, FNFImaginativeAudioMeta> {
	public static function __getFormat():FormatData {
		return {
			ID: FNF_IMAGINATIVE,
			name: "FNF (Imaginative)",
			description: "Divided per strumline FNF format with lots of metadata.",
			extension: "json",
			hasMetaFile: TRUE,
			metaFileExtension: "json",
			specialValues: [''],
			handler: FNFImaginative,
			formatFile: FNFMaru.formatFile
		}
	}

	public function new(?data:FNFImaginativeChart, ?meta:FNFImaginativeAudioMeta) {
		super({timeFormat: STEPS, supportsDiffs: false, supportsEvents: true});
		this.data = data;
		this.meta = meta;
		beautify = true;
	}

	public static function formatTitle(title:String):String
		return Path.normalize(title);
}