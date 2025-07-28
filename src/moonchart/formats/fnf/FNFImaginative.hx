package moonchart.formats.fnf;

import haxe.io.Path;
import flixel.util.FlxColor;
import flixel.util.typeLimit.OneOfFour;
import moonchart.backend.FormatData;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy.FNFLegacyMetaValues;

// Chart
typedef FNFImaginativeNote = {
	/**
	 * The note direction id.
	 */
	var id:Int;
	/**
	 * NOTE: As of rn this is actually in milliseconds!!!!!
	 * The length of a sustain in steps.
	 */
	@:default(0) var length:Float;
	/**
	 * NOTE: As of rn this is actually in milliseconds!!!!!
	 * The note position in steps.
	 */
	var time:Float;
	/**
	 * Characters this note will mess with instead of the fields main ones.
	 */
	var ?characters:Array<String>;
	/**
	 * The note type.
	 */
	var type:String;
}

typedef FNFImaginativeArrowField = {
	/**
	 * The arrow field tag name.
	 */
	var tag:String;
	/**
	 * Characters to be assigned as singers for this field.
	 */
	var characters:Array<String>;
	/**
	 * Array of notes to load.
	 */
	var notes:Array<FNFImaginativeNote>;
	/**
	 * The independent field scroll speed.
	 */
	var ?speed:Float;
}

typedef FNFImaginativeCharacter = {
	/**
	 * The character tag name.
	 */
	var tag:String;
	/**
	 * The character to load.
	 */
	@:default('boyfriend') var name:String;
	/**
	 * The location the character will be placed.
	 */
	var position:String;
	/**
	 * The character's vocal suffix override.
	 */
	var ?vocals:String;
}

typedef FNFImaginativeFieldSettings = {
	/**
	 * The starting camera target
	 */
	var ?cameraTarget:String;
	/**
	 * The arrow field order.
	 */
	var order:Array<String>;
	/**
	 * The enemy field.
	 */
	var enemy:String;
	/**
	 * The player field.
	 */
	var player:String;
}

typedef FNFImaginativeEvent = {
	/**
	 * The event name.
	 */
	var name:String;
	/**
	 * The event parameters.
	 */
	var params:Array<OneOfFour<Int, Float, Bool, String>>;
	/**
	 * NOTE: As of rn this is actually in milliseconds!!!!!
	 * The event position in steps.
	 */
	var time:Float;
	/**
	 * This is used for event stacking detection.
	 */
	@:default(0) var ?sub:Int;
}

typedef FNFImaginativeChart = {
	/**
	 * The song scroll speed.
	 */
	@:default(2.6) var speed:Float;
	/**
	 * The stage this song will take place.
	 */
	@:default('void') var stage:String;
	/**
	 * Array of arrow fields to load.
	 */
	var fields:Array<FNFImaginativeArrowField>;
	/**
	 * Array of characters to load.
	 */
	var characters:Array<FNFImaginativeCharacter>;
	/**
	 * Field settings.
	 */
	var fieldSettings:FNFImaginativeFieldSettings;
	/**
	 * Chart specific events.
	 */
	var ?events:Array<FNFImaginativeEvent>;
}

// Meta
typedef FNFImaginativeCheckpoint = { // used for bpm changes
	/**
	 * The position of the song in milliseconds.
	 */
	var time:Float;
	/**
	 * The "beats per minute" at that point.
	 */
	var bpm:Float;
	/**
	 * The time signature at that point.
	 */
	var signature:Array<Int>;
}

typedef FNFImaginativeAllowedModes = {
	/**
	 * If true, this song allows you to play as the enemy.
	 */
	@:default(false) var playAsEnemy:Bool;
	/**
	 * If true, this song allows you to go against another player.
	 */
	@:default(false) var p2AsEnemy:Bool;
}

typedef FNFImaginativeAudioMeta = {
	/**
	 * The composer of the song.
	 */
	@:default('Unassigned') var artist:String;
	/**
	 * The display name of the song.
	 */
	var name:String;
	/**
	 * The bpm at the start of the song.
	 */
	@:default(100) var bpm:Float;
	/**
	 * The time signature at the start of the song.
	 */
	@:default([4, 4]) var signature:Array<Int>;
	/**
	 * The audio offset.
	 */
	@:default(0) var ?offset:Float;
	/**
	 * Contains all known bpm changes.
	 */
	var checkpoints:Array<FNFImaginativeCheckpoint>;
}

typedef FNFImaginativeSongMeta = {
	/**
	 * The song display name.
	 */
	var name:String;
	/**
	 * The song folder name.
	 */
	var folder:String;
	/**
	 * The song icon.
	 */
	var icon:String;
	/**
	 * The starting difficulty.
	 */
	var startingDiff:Int;
	/**
	 * The difficulties listing.
	 */
	var difficulties:Array<String>;
	/**
	 * The variations listing.
	 */
	var variants:Array<String>;
	/**
	 * The song color.
	 */
	var ?color:FlxColor;
	/**
	 * Allowed modes for the song.
	 */
	var allowedModes:FNFImaginativeAllowedModes;
}

class FNFImaginative extends BasicJsonFormat<FNFImaginativeChart, FNFImaginativeAudioMeta> {
	public static function __getFormat():FormatData {
		return {
			ID: FNF_IMAGINATIVE,
			name: "FNF (Imaginative)",
			description: "A unique format for adding characters, strumlines and vocal instances.",
			extension: "json",
			hasMetaFile: TRUE,
			metaFileExtension: "json",
			specialValues: ['"speed":', '?"stage":', '_"fields":', '_"characters":', '_"fieldSettings":'],
			formatFile: FNFMaru.formatFile,
			handler: FNFImaginative
		}
	}

	public function new(?data:FNFImaginativeChart, ?meta:FNFImaginativeAudioMeta) {
		// will be in STEPS but idk how to fully do in my engine as of rn
		super({timeFormat: MILLISECONDS, supportsDiffs: false, supportsEvents: true});
		this.data = data;
		this.meta = meta;
		beautify = true;
	}

	public static function formatTitle(title:String):String
		return Path.normalize(title);

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFImaginative {
		var chartResolve:DiffNotesOutput = resolveDiffsNotes(chart, diff);
		var diffId:String = chartResolve.diffs[0];
		var basicNotes:Array<BasicNote> = chartResolve.notes.get(diffId);
		var basicMeta:BasicMetaData = chart.meta;

		var characters:Array<FNFImaginativeCharacter> = [];
		var charCap:Int = basicMeta.extraData.exists(FNFLegacyMetaValues.PLAYER_3) ? 3 : (basicMeta.extraData.get(FNFLegacyMetaValues.PLAYER_3) == null ? 2 : 3);
		for (i in 0...charCap) {
			characters.push({
				tag: switch (i) {
					case 0: 'enemy';
					case 1: 'player';
					case 2: 'spectator';
					default: 'UNKNOWN';
				},
				name: switch (i) {
					case 0: basicMeta.extraData.get(FNFLegacyMetaValues.PLAYER_1) ?? 'dad';
					case 1: basicMeta.extraData.get(FNFLegacyMetaValues.PLAYER_2) ?? 'boyfriend';
					case 2: basicMeta.extraData.get(FNFLegacyMetaValues.PLAYER_3) ?? 'gf';
					default: '';
				},
				position: switch (i) {
					case 0: 'enemy';
					case 1: 'player';
					case 2: 'spectator';
					default: 'UNKNOWN';
				},
			});
		}

		var fields:Array<FNFImaginativeArrowField> = [];
		for (i in 0...2) {
			fields.push({
				tag: characters[i].tag,
				characters: [characters[i].tag],
				notes: []
			});
		}

		for (note in basicNotes) {
			var field:FNFImaginativeArrowField = fields[Std.int(note.lane / 4)];
			if (field == null)
				continue;

			field.notes.push({
				id: note.lane % 4,
				length: note.length,
				time: note.time,
				type: note.type
			});
		}

		data = {
			speed: basicMeta.scrollSpeeds.get(diffId) ?? Util.mapFirst(basicMeta.scrollSpeeds) ?? 2.6,
			stage: basicMeta.extraData.get(FNFLegacyMetaValues.STAGE) ?? 'void',
			fields: fields,
			characters: characters,
			fieldSettings: {
				cameraTarget: 'enemy',
				order: ['enemy', 'player'],
				enemy: 'enemy',
				player: 'player'
			},
			events: []//chart.data.events
		}

		var bpmChanges:Array<BasicBPMChange> = basicMeta.bpmChanges;
		var initChange:BasicBPMChange = bpmChanges.shift();
		meta = {
			artist: basicMeta.extraData.get(SONG_ARTIST) ?? Moonchart.DEFAULT_ARTIST,
			name: basicMeta.title,
			bpm: initChange.bpm,
			signature: [Std.int(initChange.stepsPerBeat), Std.int(initChange.beatsPerMeasure)],
			offset: basicMeta.offset,
			checkpoints: [
				for (change in bpmChanges) {
					{
						time: change.time,
						bpm: change.bpm,
						signature: [Std.int(change.stepsPerBeat), Std.int(change.beatsPerMeasure)]
					}
				}
			]
		}

		return this;
	}
}