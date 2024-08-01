package moonchart.formats.fnf.legacy;

import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.FNFVSlice;
import haxe.Json;

typedef FNFLegacyFormat =
{
	song:String,
	bpm:Float,
	speed:Float,
	needsVoices:Bool,
	validScore:Bool,
	player1:String,
	player2:String,
	notes:Array<FNFLegacySection>
}

typedef FNFLegacySection =
{
	mustHitSection:Bool,
	lengthInSteps:Int,
	sectionNotes:Array<FNFLegacyNote>,
	altAnim:Bool,
	changeBPM:Bool,
	bpm:Float
}

// TODO: FNF legacy and vslice (?) have the quirk of having lengths be 1 step crochet behind their actual length
// Should prob account for those, specially since formats like stepmania exist that require very specific hold lengths

abstract FNFLegacyNote(Array<Dynamic>) from Array<Dynamic> to Array<Dynamic>
{
	public var time(get, never):Float;
	public var lane(get, never):Int;
	public var length(get, never):Float;
	public var type(get, never):Dynamic;

	function get_time():Float
	{
		return this[0];
	}

	function get_lane():Int
	{
		return this[1];
	}

	function get_length():Float
	{
		return this[2];
	}

	function get_type():Dynamic
	{
		return this[3];
	}
}

enum abstract FNFLegacyNoteType(String) from String to String
{
	var DEFAULT = "";
	var ALT_ANIM = "ALT_ANIM";
	var HURT = "HURT";
}

enum abstract FNFLegacyEvent(String) from String to String
{
	var MUST_HIT_SECTION = "FNF_MUST_HIT_SECTION";
}

enum abstract FNFLegacyMetaValues(String) from String to String
{
	var PLAYER_1 = "FNF_P1";
	var PLAYER_2 = "FNF_P2";
	var PLAYER_3 = "FNF_P3";
	var STAGE = "FNF_STAGE";
	var NEEDS_VOICES = "FNF_NEEDS_VOICES";
}

typedef FNFLegacy = FNFLegacyBasic<FNFLegacyFormat>;

class FNFLegacyBasic<T:FNFLegacyFormat> extends BasicFormat<{song:T}, {}>
{
	public function new(?data:{song:T}, ?diff:String)
	{
		super({timeFormat: MILLISECONDS, supportsEvents: true});
		this.data = data;
		this.diff = diff;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:String):FNFLegacyBasic<T>
	{
		diff ??= this.diff;
		var diffChart = Timing.resolveDiffNotes(chart, diff);
		var meta = chart.meta;
		var initBpm = meta.bpmChanges[0].bpm;

		var notes:Array<FNFLegacySection> = [];
		var measures = Timing.divideNotesToMeasures(diffChart, chart.data.events, meta.bpmChanges);

		// Take out must hit events
		chart.data.events = chart.data.events.filter((event) -> return event.name != MUST_HIT_SECTION);

		var lastBpm = initBpm;
		var lastMustHit:Bool = true;
		var nextMustHit:Null<Bool> = null;

		for (measure in measures)
		{
			var mustHit:Bool = lastMustHit;

			if (nextMustHit != null)
			{
				mustHit = nextMustHit;
				nextMustHit = null;
			}

			// Push must hit events
			for (event in measure.events)
			{
				// Check if measure has a must hit event
				var eventMustHit:Null<Bool> = resolveMustHitEvent(event);

				if (eventMustHit != null)
				{
					var eventTime = (event.time - measure.startTime);
					if (eventTime < measure.length / 2)
					{
						mustHit = eventMustHit;
						nextMustHit = null;
					}
					else
					{
						// Event happens too late, save it for the next measure (aprox)
						nextMustHit = eventMustHit;
					}
				}
			}

			// Create legacy section
			var section:FNFLegacySection = {
				sectionNotes: [],
				mustHitSection: mustHit,
				lengthInSteps: measure.stepsPerBeat * measure.beatsPerMeasure,
				altAnim: false,
				changeBPM: false,
				bpm: 0.0
			}

			lastMustHit = mustHit;

			// Section has a bpm change event (aprox)
			if (measure.bpm != lastBpm)
			{
				section.changeBPM = true;
				section.bpm = measure.bpm;
				lastBpm = measure.bpm;
			}

			var stepCrochet = Timing.stepCrochet(measure.bpm, measure.stepsPerBeat);

			// Push notes to section
			while (measure.notes.length > 0)
			{
				var note = measure.notes.shift();

				var lane:Int = mustHitLane(mustHit, note.lane);
				var length:Float = note.length > 0 ? Math.max(note.length - stepCrochet, 0) : 0;

				var fnfNote:FNFLegacyNote = [note.time, lane, length, note.type];
				section.sectionNotes.push(fnfNote);
			}

			notes.push(section);
		}

		this.data = cast {
			song: {
				song: meta.title,
				bpm: initBpm,
				speed: meta.extraData.get(SCROLL_SPEED) ?? 1.0,
				needsVoices: meta.extraData.get(NEEDS_VOICES) ?? false,
				validScore: true,
				player1: meta.extraData.get(PLAYER_1) ?? "bf",
				player2: meta.extraData.get(PLAYER_2) ?? "dad",
				notes: notes
			}
		};

		return this;
	}

	function resolveNoteType(note:FNFLegacyNote):String
	{
		if (note.type is String)
		{
			return note.type;
		}

		return switch (cast(note.type, Int))
		{
			case 0: DEFAULT;
			case 1: ALT_ANIM;
			case _: DEFAULT;
		}
	}

	override function getNotes():Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var stepCrochet = Timing.stepCrochet(data.song.bpm, 4);

		for (section in data.song.notes)
		{
			if (section.changeBPM)
			{
				stepCrochet = Timing.stepCrochet(section.bpm, 4);
			}

			for (note in section.sectionNotes)
			{
				var lane:Int = mustHitLane(section.mustHitSection, note.lane);
				var length:Float = note.length > 0 ? note.length + stepCrochet : 0;
				var type:String = section.altAnim ? ALT_ANIM : resolveNoteType(note);

				notes.push({
					time: note.time,
					lane: lane,
					length: length,
					type: type
				});
			}
		}

		Timing.sortNotes(notes);

		return notes;
	}

	function resolveMustHitEvent(event:BasicEvent):Null<Bool>
	{
		return switch (event.name)
		{
			case MUST_HIT_SECTION:
				event.data.mustHitSection ?? true;
			case FNFVSlice.VSLICE_FOCUS_EVENT:
				(Std.string(event.data.char) == "0");
			case _:
				null;
		}
	}

	function mustHitLane(mustHit:Bool, lane:Int):Int
	{
		// TODO: Maybe some add some metadata for extrakey formats?
		return (mustHit ? lane : (lane + 4) % 8);
	}

	public static function makeMustHitSectionEvent(time:Float, mustHit:Bool):BasicEvent
	{
		return {
			time: time,
			name: MUST_HIT_SECTION,
			data: {
				mustHitSection: mustHit
			}
		}
	}

	override function getEvents():Array<BasicEvent>
	{
		var events:Array<BasicEvent> = [];

		var time:Float = 0;
		var crochet = Timing.measureCrochet(data.song.bpm, 4);

		for (section in data.song.notes)
		{
			events.push(makeMustHitSectionEvent(time, section.mustHitSection));

			if (section.changeBPM)
			{
				var beats:Int = sectionBeats(section);
				crochet = Timing.measureCrochet(section.bpm, beats);
			}

			time += crochet;
		}

		return events;
	}

	function sectionBeats(?section:FNFLegacySection):Int
	{
		return Std.int((section?.lengthInSteps ?? 16) / 4);
	}

	override function getChartData():BasicChartData
	{
		var diffs = new BasicChartDiffs();
		var notes = getNotes();
		diffs.set(diff, notes);

		return {
			diffs: diffs,
			events: getEvents()
		}
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		var time:Float = 0.0;
		var bpm:Float = data.song.bpm;
		var beats:Int = sectionBeats(data.song.notes[0]);
		bpmChanges.push({
			time: time,
			bpm: bpm,
			beatsPerMeasure: beats,
			stepsPerBeat: 4
		});

		for (section in data.song.notes)
		{
			beats = sectionBeats(data.song.notes[0]);

			if (section.changeBPM)
			{
				bpm = section.bpm;
				bpmChanges.push({
					time: time,
					bpm: bpm,
					beatsPerMeasure: beats,
					stepsPerBeat: 4
				});
			}

			time += Timing.measureCrochet(bpm, beats);
		}

		Timing.sortBPMChanges(bpmChanges);

		return {
			title: data.song.song,
			bpmChanges: bpmChanges,
			extraData: [
				PLAYER_1 => data.song.player1,
				PLAYER_2 => data.song.player2,
				SCROLL_SPEED => data.song.speed,
				NEEDS_VOICES => data.song.needsVoices
			]
		}
	}

	override function stringify()
	{
		return {
			data: Json.stringify(data),
			meta: Json.stringify(meta)
		}
	}

	public override function fromFile(path:String, ?meta:String, ?diff:String):FNFLegacyBasic<T>
	{
		return fromJson(Util.getText(path), meta, diff ?? this.diff);
	}

	public function fromJson(data:String, ?meta:String, diff:String):FNFLegacyBasic<T>
	{
		this.diff = diff;
		this.data = Json.parse(data);
		return this;
	}
}
