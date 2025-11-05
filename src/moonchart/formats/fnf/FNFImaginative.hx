package moonchart.formats.fnf;

import haxe.io.Path;
import flixel.util.FlxColor;
import flixel.util.typeLimit.OneOfFour;
import moonchart.backend.FormatData;
import moonchart.backend.Optimizer;
import moonchart.backend.Timing;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.FNFGlobal;
import moonchart.formats.fnf.legacy.FNFLegacy;

// Chart
typedef FNFImaginativeNote = {
	/**
	 * The note direction id.
	 */
	var id:Int;
	// NOTE: As of rn this is actually in milliseconds!!!!!
	/**
	 * The length of a sustain in steps.
	 */
	@:default(0) var length:Float;
	// NOTE: As of rn this is actually in milliseconds!!!!!
	/**
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
	/**
	 * The starting strum count of the field.
	 */
	@:default('4') var ?startCount:Int;
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
	// NOTE: As of rn this is actually in milliseconds!!!!!
	/**
	 * The event position in steps.
	 */
	var time:Float;
	/**
	 * Each event to trigger.
	 */
	var data:Array<FNFImaginativeSubEvent>;
}
typedef FNFImaginativeSubEvent = {
	/**
	 * The event name.
	 */
	var name:String;
	/**
	 * The event parameters.
	 */
	var params:Array<Dynamic>;
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

enum abstract FNFImaginativeNoteType(String) from String to String {
	var IMAG_ALT_ANIM = "Alt Animation";
	var IMAG_NO_ANIM = "No Animation";
}

class FNFImaginative extends BasicJsonFormat<FNFImaginativeChart, FNFImaginativeAudioMeta> {
	public static function __getFormat():FormatData {
		return {
			ID: FNF_IMAGINATIVE,
			name: 'FNF (Imaginative)',
			description: 'A unique format for adding characters, strumlines and vocal instances.',
			extension: 'json',
			hasMetaFile: TRUE,
			metaFileExtension: 'json',
			specialValues: ['"speed":', '?"stage":', '_"fields":', '_"characters":', '_"fieldSettings":'],
			formatFile: FNFMaru.formatFile,
			handler: FNFImaginative
		}
	}

	public var noteTypeResolver(default, null):FNFNoteTypeResolver;

	public function new(?data:FNFImaginativeChart, ?meta:FNFImaginativeAudioMeta) {
		// NOTE: will be in STEPS but idk how to fully do that as of rn
		super({timeFormat: MILLISECONDS, supportsDiffs: false, supportsEvents: true});
		this.data = data;
		this.meta = meta;
		beautify = true;

		noteTypeResolver = FNFGlobal.createNoteTypeResolver();
		noteTypeResolver.register(FNFImaginativeNoteType.IMAG_ALT_ANIM, BasicFNFNoteType.ALT_ANIM);
		noteTypeResolver.register(FNFImaginativeNoteType.IMAG_NO_ANIM, BasicFNFNoteType.NO_ANIM);
	}

	public static function formatTitle(title:String):String
		return Path.normalize(title);

	inline static var _UNKNOWN_:String = '[unknown]';
	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFImaginative {
		var chartResolve:DiffNotesOutput = resolveDiffsNotes(chart, diff);
		var diffId:String = chartResolve.diffs[0];
		var basicMeta:BasicMetaData = chart.meta;

		var characters:Array<FNFImaginativeCharacter> = Util.makeArray(0);
		var charCap:Int = basicMeta.extraData.exists(FNFLegacyMetaValues.PLAYER_3) ? 3 : (basicMeta.extraData.get(FNFLegacyMetaValues.PLAYER_3) == null ? 2 : 3);
		for (i in 0...charCap) {
			characters.push({
				tag: switch (i) {
					case 0: 'enemy';
					case 1: 'player';
					case 2: 'spectator';
					default: _UNKNOWN_;
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
					default: _UNKNOWN_;
				},
			});
		}

		var fields:Array<FNFImaginativeArrowField> = Util.makeArray(0);
		for (i in 0...2) {
			fields.push({
				tag: characters[i].tag,
				characters: [characters[i].tag],
				notes: Util.makeArray(0)
			});
		}

		var basicNotes:Array<BasicNote> = Timing.sortNotes(chartResolve.notes.get(diffId));
		for (note in basicNotes) {
			var field:FNFImaginativeArrowField = fields[Std.int(note.lane / 4)];
			if (field == null) continue;
			field.notes.push({
				id: note.lane % 4,
				length: note.length,
				time: note.time,
				type: note.type
			});
		}
		for (field in fields) field.notes.sort((a, b) -> return Util.sortValues(a.time, b.time));

		var events:Array<FNFImaginativeEvent> = Util.makeArray(0);
		var basicEvents = /* Timing.sortEvents */(chart.data.events);
		// trace(haxe.Json.stringify(basicEvents, '\t'));
		for (i => event in basicEvents) {
			// helper for making events for imaginative
			inline function makeEvent(name:String, params:Array<Dynamic>):Void {
				if (i - 1 > -1 && event.time == events[i - 1].time) {
					// doing psychs event stacking method
					events[i - 1].data.push({name: name, params: params});
				} else {
					events.push({
						time: event.time,
						data: [
							{name: name, params: params}
						]
					});
				}
			}

			// vslice conversion process
			if (basicMeta.inputFormats.contains(FNF_VSLICE)) {
				switch (event.name) {
					case 'FocusCamera':
						var target:Int = event.data?.char ?? 0;
						var x:Float = event.data?.x ?? 0;
						var y:Float = event.data?.y ?? 0;
						var duration:Float = event.data?.duration ?? 4;
						var ease:String = event.data?.ease ?? '[none]';
						if (ease == 'INSTANT') ease = '[instant]';
						if (ease == 'CLASSIC') ease = '[none]';

						if (target == -1)
							makeEvent('Focus Camera To Custom Position', [x, y, duration, ease, /* _UNKNOWN_, false, */ 'disable']);
						else
							makeEvent('Focus Camera To Character', [
								'character',
								switch (target) {
									case 0: 'player';
									case 1: 'enemy';
									case 2: 'spectator';
									default: _UNKNOWN_;
								},
								x, y, duration, ease,
								// _UNKNOWN_, false, // idr wtf these where 😭
								'disable' // how camera displacement should act when tweening if its enabled
							]);

					case 'PlayAnimation':
						var target:String = event.data?.target ?? 'player';
						target = switch (target) {
							case 'boyfriend' | 'bf': 'player';
							case 'dad' | 'opponent': 'enemy';
							case 'girlfriend' | 'gf': 'spectator';
							default: target;
						}
						makeEvent('Play Sprite Animation', [
							target == 'enemy' || target == 'player' || target == 'spectator' ? 'character' : 'sprite',
							target,
							event.data?.anim ?? _UNKNOWN_,
							'Unclear', // animation context
							event.data?.force ?? false,
							false, // reversed
							0 // starting frame
						]);

					case 'ScrollSpeed':
						var target:String = switch (event.data?.strumline) {
							case 'opponent': 'enemy';
							case 'player': 'player';
							default: '[global]';
						}
						var ease:String = event.data?.ease ?? 'linear';
						if (ease == 'INSTANT') ease = '[instant]';
						makeEvent('Manage Scroll Speed', [
							target,
							event.data?.scroll ?? 1,
							event.data?.duration ?? 4,
							ease,
							event.data?.absolute ?? false,
						]);

					case 'SetCameraBop':
						// TODO: Write this.

					// case 'SetCharacter':
						// TODO: Write this.

					case 'SetHealthIcon':
						var target:Int = event.data?.char ?? 0;
						var iconId:String = event.data?.id ?? 'boyfriend';
						// MAYBE: Write this?

					// case 'SetStage':
						// TODO: Write this.

					case 'ZoomCamera':
						var ease:String = event.data?.ease ?? 'linear';
						if (ease == 'INSTANT') ease = '[instant]';
						// sets the default zoom and lerps handle the rest
						// if (ease == 'CLASSIC') ease = '[none]';
						makeEvent('Manage Camera Zoom', [
							event.data?.zoom ?? 1,
							event.data?.duration ?? 4,
							ease,
							(event.data?.mode ?? 'stage') == 'stage'
						]);
					default:
						// UNKNOWN
				}
			}
			// psych conversion process
			if (basicMeta.inputFormats.contains(FNF_LEGACY_PSYCH)) {
				switch (event.name) {
					case 'Play Animation':
						/* makeEvent('Play Sprite Animation', [
							//
						]); */
					default:
						// UNKNOWN
				}
				// TODO: Write this.
			}
			if (basicMeta.inputFormats.contains(FNF_CODENAME)) {
				// codename conversion process
				// TODO: Write this.
			}
			// jic
			if (basicMeta.inputFormats.contains(FNF_IMAGINATIVE)) {
				// TODO: Write this.
			}
		}
		events.sort((a, b) -> return Util.sortValues(a.time, b.time));
		// trace(haxe.Json.stringify(events, '\t'));

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
			events: events
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

	override function getNotes(?diff:String):Array<BasicNote> {
		var notes:Array<BasicNote> = Util.makeArray(0);
		for (field in data.fields)
			for (note in field.notes)
				notes.push({
					time: note.time,
					lane: note.id,
					length: note.length,
					type: note.type
				});
		Timing.sortNotes(notes);
		return notes;
	}

	override function getEvents():Array<BasicEvent> {
		var events:Array<BasicEvent> = Util.makeArray(0);
		for (event in data.events)
			for (data in event.data)
				events.push(Util.makeArrayEvent(event.time, data.name, data.params));
		Timing.sortEvents(events);
		return events;
	}

	function getArrowField(tags:Array<String>):FNFImaginativeArrowField {
		for (field in data.fields)
			if (tags.contains(field.tag))
				return field;
		return null;
	}

	override function getChartMeta():BasicMetaData {
		var bpmChanges:Array<BasicBPMChange> = [
			{
				time: 0,
				bpm: meta.bpm,
				stepsPerBeat: meta.signature[0],
				beatsPerMeasure: meta.signature[1]
			}
		];
		for (checkpoint in meta.checkpoints)
			bpmChanges.push({
				time: checkpoint.time,
				bpm: checkpoint.bpm,
				stepsPerBeat: checkpoint.signature[0],
				beatsPerMeasure: checkpoint.signature[1]
			});
		Timing.sortBPMChanges(bpmChanges);
		return {
			title: meta.name,
			bpmChanges: bpmChanges,
			offset: 0,
			scrollSpeeds: [diffs[0] => data.speed],
			extraData: [
				PLAYER_1 => getArrowField(['player', 'boyfriend', 'bf'])?.characters[0] ?? 'boyfriend',
				PLAYER_2 => getArrowField(['enemy', 'opponent', 'dad'])?.characters[0] ?? 'dad',
				PLAYER_3 => getArrowField(['spectator', 'gf', 'girlfriend'])?.characters[0] ?? 'gf',
				SONG_ARTIST => meta.artist ?? Moonchart.DEFAULT_ARTIST,
				SONG_CHARTER => Moonchart.DEFAULT_CHARTER, // no variable for this yet
				STAGE => data.stage
			]
		}
	}

	override function fromFile(path:String, ?meta:StringInput, ?diff:FormatDifficulty):FNFImaginative {
		return fromJson(Util.getText(path), Util.getText(meta), diff);
	}

	override function fromJson(data:String, ?meta:StringInput, ?diff:FormatDifficulty):FNFImaginative {
		super.fromJson(data, meta, diff);
		Optimizer.addDefaultValues(this.data, {
			fields: [for (i in 0...2) {tag: i == 0 ? 'enemy' : 'player', characters: [i == 0 ? 'enemy' : 'player'], notes: Util.makeArray(0)}],
			characters: [for (i in 0...2) {tag: i == 0 ? 'enemy' : 'player', position: _UNKNOWN_}],
			fieldSettings: {cameraTarget: 'player', order: ['enemy', 'player'], enemy: 'enemy', player: 'player'}
		});
		return this;
	}
}