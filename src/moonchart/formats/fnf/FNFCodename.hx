package moonchart.formats.fnf;

import moonchart.backend.Optimizer;
import moonchart.backend.FormatData;
import moonchart.backend.Timing;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;

typedef FNFCodenameFormat =
{
	codenameChart:Bool,
	scrollSpeed:Float,
	validScore:Bool,
	stage:String,
	noteTypes:Array<String>,
	strumLines:Array<FNFCodenameStrumline>,
	events:Array<FNFCodenameEvent>
}

typedef FNFCodenameStrumline =
{
	position:String,
	strumScale:Float,
	visible:Bool,
	type:Int,
	characters:Array<String>,
	strumPos:Array<Float>,
	strumLinePos:Float,
	vocalsSuffix:String,
	notes:Array<FNFCodenameNote>
}

typedef FNFCodenameNote =
{
	time:Float,
	id:Int,
	sLen:Float,
	type:Int
}

typedef FNFCodenameEvent =
{
	time:Float,
	name:String,
	params:Array<Dynamic>
}

typedef FNFCodenameMeta =
{
	opponentModeAllowed:Bool,
	coopAllowed:Bool,
	stepsPerBeat:Int,
	beatsPerMesure:Int,
	bpm:Float,
	difficulties:Array<String>,
	needsVoices:Bool,
	parsedColor:Int,
	displayName:String,
	customValues:FNFCodenameCustom,
	icon:String,
	name:String,
	color:String
}

typedef FNFCodenameCustom =
{
	composers:String
}

// TODO: support for psych gf notes / sections converted to the gf strumline?

class FNFCodename extends BasicJsonFormat<FNFCodenameFormat, FNFCodenameMeta>
{
	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_CODENAME,
			name: "FNF (Codename)",
			description: "",
			extension: "json",
			hasMetaFile: POSSIBLE,
			metaFileExtension: "json",
			specialValues: ['"codenameChart":'],
			handler: FNFCodename
		}
	}

	public static inline var CODENAME_BPM_CHANGE:String = "BPM Change";
	public static inline var CODENAME_CAM_MOVEMENT:String = "Camera Movement";

	public function new(?data:FNFCodenameFormat, ?meta:FNFCodenameMeta)
	{
		super({timeFormat: MILLISECONDS, supportsDiffs: true, supportsEvents: true});
		this.data = data;
		this.meta = meta;
		beautify = true;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFCodename
	{
		var chartResolve = resolveDiffsNotes(chart, diff);
		var diff:String = chartResolve.diffs[0];
		var basicNotes:Array<BasicNote> = chartResolve.notes.get(diff);

		var meta = chart.meta;

		var strumlines:Array<FNFCodenameStrumline> = [];
		var events:Array<FNFCodenameEvent> = [];

		// Creating by default 3 strumlines (dad, bf, gf)
		// May need to rework the method down the line

		for (i in 0...3)
		{
			strumlines.push({
				position: ["dad", "boyfriend", "girlfriend"][i],
				strumScale: 1,
				visible: i < 2,
				type: i,
				characters: [
					switch (i)
					{
						case 0:
							meta.extraData.get(PLAYER_2) ?? "dad";
						case 1:
							meta.extraData.get(PLAYER_1) ?? "bf";
						default:
							meta.extraData.get(PLAYER_3) ?? "gf";
					}
				],
				strumPos: [0, 50],
				strumLinePos: switch (i)
				{
					case 1: 0.75;
					default: 0.25;
				},
				vocalsSuffix: "",
				notes: []
			});
		}

		var noteTypes:Array<String> = [];

		for (note in basicNotes)
		{
			var lane:Int = note.lane;
			var strumline:FNFCodenameStrumline = strumlines[Std.int(lane / 4)];

			if (strumline == null)
				continue;

			var type:Int = resolveCodenameType(note.type, noteTypes);
			var id:Int = lane % 4;

			strumline.notes.push({
				time: note.time,
				id: id,
				sLen: note.length,
				type: type
			});
		}

		// Push normal events / cam movement events

		for (event in chart.data.events)
		{
			final isFocus:Bool = FNFVSlice.isCamFocusEvent(event) && event.name != CODENAME_CAM_MOVEMENT;
			events.push(isFocus ? {
				time: event.time,
				name: CODENAME_CAM_MOVEMENT,
				params: [resolveCamFocus(event)]
			} : {
				time: event.time,
				name: event.name,
				params: Util.resolveEventValues(event.data)
				});
		}

		// Push bpm change events

		for (i in 1...chart.meta.bpmChanges.length)
		{
			final bpmChange = chart.meta.bpmChanges[i];
			events.push({
				time: bpmChange.time,
				name: CODENAME_BPM_CHANGE,
				params: [bpmChange.bpm]
			});
		}

		events.sort((a, b) -> return Util.sortValues(a.time, b.time));

		// Finally add all the data

		this.data = {
			codenameChart: true,
			scrollSpeed: meta.scrollSpeeds.get(diff) ?? 1.0,
			validScore: true,
			stage: meta.extraData.get(STAGE) ?? "stage",
			noteTypes: noteTypes,
			strumLines: strumlines,
			events: events
		}

		this.meta = {
			opponentModeAllowed: true,
			coopAllowed: true,
			stepsPerBeat: Std.int(chart.meta.bpmChanges[0].stepsPerBeat),
			beatsPerMesure: Std.int(chart.meta.bpmChanges[0].beatsPerMeasure),
			bpm: chart.meta.bpmChanges[0].bpm,
			difficulties: this.diffs,
			needsVoices: meta.extraData.get(NEEDS_VOICES) ?? false,
			parsedColor: 0,
			displayName: meta.title,
			customValues: {
				composers: meta.extraData.get(SONG_ARTIST) ?? "Unknown"
			},
			icon: "bf",
			name: formatSongName(meta.title),
			color: ""
		}

		return this;
	}

	function resolveCamFocus(event:BasicEvent):Int
	{
		return switch (FNFVSlice.resolveCamFocus(event))
		{
			case DAD: 0;
			case BF: 1;
			case GF: 2;
		}
	}

	inline function formatSongName(name:String):String
	{
		return name.toLowerCase();
	}

	function resolveCodenameType(type:String, list:Array<String>):Int
	{
		if (type.length <= 0)
			return 0;

		if (list.contains(type))
			return list.indexOf(type);

		list.push(type);
		return list.length - 1;
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		for (i => strumline in data.strumLines)
		{
			for (note in strumline.notes)
			{
				var lane:Int = note.id + (4 * i);
				notes.push({
					time: note.time,
					lane: lane,
					length: note.sLen,
					type: data.noteTypes[note.type] ?? ""
				});
			}
		}

		Timing.sortNotes(notes);
		return notes;
	}

	override function getEvents():Array<BasicEvent>
	{
		var events:Array<BasicEvent> = [];

		for (event in data.events)
		{
			if (event.name != CODENAME_BPM_CHANGE)
				events.push(Util.makeArrayEvent(event.time, event.name, event.params));
		}

		// Set the default init cam movement
		events.unshift({
			time: -1,
			name: CODENAME_CAM_MOVEMENT,
			data: {
				array: [0]
			}
		});

		return events;
	}

	function getStrumline(position:String):FNFCodenameStrumline
	{
		for (strumline in data.strumLines)
		{
			if (strumline.position == position)
				return strumline;
		}

		return null;
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [
			{
				time: -1,
				bpm: meta.bpm,
				stepsPerBeat: meta.stepsPerBeat,
				beatsPerMeasure: meta.beatsPerMesure
			}
		];

		for (event in data.events)
		{
			if (event.name == CODENAME_BPM_CHANGE)
			{
				bpmChanges.push({
					time: event.time,
					bpm: event.params[0],
					stepsPerBeat: meta.stepsPerBeat,
					beatsPerMeasure: meta.beatsPerMesure
				});
			}
		}

		Timing.sortBPMChanges(bpmChanges);

		return {
			title: meta.displayName,
			bpmChanges: bpmChanges,
			offset: 0.0,
			scrollSpeeds: [diffs[0] => data.scrollSpeed],
			extraData: [
				PLAYER_1 => getStrumline("boyfriend").characters[0],
				PLAYER_2 => getStrumline("dad").characters[0],
				PLAYER_3 => getStrumline("girlfriend").characters[0],
				STAGE => data.stage
			]
		}
	}

	public override function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):FNFCodename
	{
		return fromJson(Util.getText(path), Util.getText(meta), diff);
	}

	public override function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFCodename
	{
		super.fromJson(data, meta, diff);

		Optimizer.addDefaultValues(this.data, {
			events: []
		});

		this.diffs = diff ?? this.meta.difficulties;
		return this;
	}
}
