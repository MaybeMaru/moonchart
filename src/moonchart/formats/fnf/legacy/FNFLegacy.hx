package moonchart.formats.fnf.legacy;

import moonchart.backend.FormatData;
import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.FNFVSlice;
import haxe.Json;

using StringTools;

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
	public var time(get, set):Float;
	public var lane(get, set):Int;
	public var length(get, set):Float;
	public var type(get, set):OneOfTwo<String, Int>;

	inline function get_time():Float
		return this[0];

	inline function get_lane():Int
		return this[1];

	inline function get_length():Float
		return this[2];

	inline function get_type():OneOfTwo<String, Int>
		return this[3];

	inline function set_time(v):Float
		return this[0] = v;

	inline function set_lane(v):Int
		return this[1] = v;

	inline function set_length(v):Float
		return this[2] = v;

	inline function set_type(v):OneOfTwo<String, Int>
		return this[3] = v;

	public static inline function make():FNFLegacyNote
	{
		return [0, 0, 0, ""];
	}
}

enum abstract FNFLegacyNoteType(String) from String to String
{
	var ALT_ANIM = "ALT_ANIM";
}

enum abstract FNFLegacyEvent(String) from String to String
{
	var MUST_HIT_SECTION = "FNF_MUST_HIT_SECTION";
	// var ALT_ANIM_SECTION = "FNF_ALT_ANIM_SECTION";
}

enum abstract FNFLegacyMetaValues(String) from String to String
{
	var PLAYER_1 = "FNF_P1";
	var PLAYER_2 = "FNF_P2";
	var PLAYER_3 = "FNF_P3";
	var STAGE = "FNF_STAGE";
	var NEEDS_VOICES = "FNF_NEEDS_VOICES";
	var VOCALS_OFFSET = "FNF_VOCALS_OFFSET";
}

class FNFLegacy extends FNFLegacyBasic<FNFLegacyFormat>
{
	/**
	 * The default must hit section value.
	 */
	public static var FNF_LEGACY_DEFAULT_MUSTHIT:Bool = true;

	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_LEGACY,
			name: "FNF (Legacy)",
			description: "The original section-based FNF format.",
			extension: "json",
			formatFile: formatFile,
			hasMetaFile: FALSE,
			handler: FNFLegacy
		};
	}

	public static function formatFile(title:String, diff:String):Array<String>
	{
		diff = diff.trim().toLowerCase();
		var diffSuffix:String = (diff == "normal") ? "" : "-" + diff;
		return [title.trim().toLowerCase() + diffSuffix];
	}

	// TODO: Maybe some add some metadata for extrakey formats?
	public static inline function mustHitLane(mustHit:Bool, lane:Int):Int
	{
		return (mustHit ? lane : (lane + 4) % 8);
	}

	public static inline function makeMustHitSectionEvent(time:Float, mustHit:Bool):BasicEvent
	{
		return {
			time: time,
			name: MUST_HIT_SECTION,
			data: {
				mustHitSection: mustHit
			}
		}
	}

	public function new(?data:{song:FNFLegacyFormat})
	{
		super(data);
		indexedTypes = true;
	}
}

@:private
@:noCompletion
class FNFLegacyBasic<T:FNFLegacyFormat> extends BasicFormat<{song:T}, {}>
{
	/**
	 * FNF (Legacy) handles sustains by being 1 step crochet behind their actual length.
	 * You can turn it off here if your legacy extended format doesn't have this quirk.
	 */
	public var offsetHolds:Bool = true;

	/**
	 * If to import the note types as ints rather than strings.
	 * Most legacy-branching formats use strings but legacy up to 0.2.7.1 used ints.
	 */
	public var indexedTypes:Bool = false;

	public function new(?data:{song:T})
	{
		super({timeFormat: MILLISECONDS, supportsDiffs: false, supportsEvents: false});
		this.data = data;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFLegacyBasic<T>
	{
		var chartResolve = resolveDiffsNotes(chart, diff);
		var diff:String = chartResolve.diffs[0];
		var basicNotes:Array<BasicNote> = chartResolve.notes.get(diff);

		final meta = chart.meta;
		final initBpm = meta.bpmChanges[0].bpm;

		final notes:Array<FNFLegacySection> = [];
		final measures = Timing.divideNotesToMeasures(basicNotes, chart.data.events, meta.bpmChanges);

		final lanesLength:Int = (meta.extraData.get(LANES_LENGTH) ?? 8) <= 7 ? 4 : 8;
		final offset:Float = meta.offset;

		// Take out must hit events
		chart.data.events = FNFVSlice.filterEvents(chart.data.events);

		var lastBpm = initBpm;
		var lastMustHit:Bool = FNFLegacy.FNF_LEGACY_DEFAULT_MUSTHIT;
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
				if (FNFVSlice.isCamFocusEvent(event))
				{
					var eventMustHit = FNFVSlice.resolveCamFocus(event) == 0;
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
				lengthInSteps: Std.int(measure.stepsPerBeat * measure.beatsPerMeasure),
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

			final stepCrochet:Float = offsetHolds ? Timing.stepCrochet(measure.bpm, measure.stepsPerBeat) : 0;

			// Push notes to section
			for (note in measure.notes)
			{
				final lane:Int = FNFLegacy.mustHitLane(mustHit, (note.lane + 4 + lanesLength) % 8);
				final length:Float = note.length > 0 ? Math.max(note.length - stepCrochet, 0) : 0;
				final type:OneOfTwo<Int, String> = resolveBasicNoteType(note.type);

				final fnfNote:FNFLegacyNote = [note.time, lane, length, type];
				section.sectionNotes.push(prepareNote(fnfNote, offset));
			}

			notes.push(section);
		}

		this.data = cast {
			song: {
				song: meta.title,
				bpm: initBpm,
				speed: meta.scrollSpeeds.get(diff) ?? 1.0,
				needsVoices: meta.extraData.get(NEEDS_VOICES) ?? false,
				validScore: true,
				player1: meta.extraData.get(PLAYER_1) ?? "bf",
				player2: meta.extraData.get(PLAYER_2) ?? "dad",
				notes: notes
			}
		};

		return this;
	}

	// Making it a function so it can be overriden for formats that do support offset values
	public function prepareNote(note:FNFLegacyNote, offset:Float):FNFLegacyNote
	{
		note.time -= offset;
		return note;
	}

	public function filterEvents(events:Array<BasicEvent>):Array<BasicEvent>
	{
		return FNFVSlice.filterEvents(events);
	}

	public function resolveBasicNoteType(type:String):OneOfTwo<Int, String>
	{
		return (!indexedTypes) ? type : switch (type)
		{
			case DEFAULT: 0;
			case ALT_ANIM: 1;
			default: 0;
		}
	}

	public function resolveNoteType(note:FNFLegacyNote):String
	{
		return (note.type is String) ? note.type : switch (cast(note.type, Int))
		{
			case 0: DEFAULT;
			case 1: ALT_ANIM;
			case _: DEFAULT;
		}
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var stepCrochet = offsetHolds ? Timing.stepCrochet(data.song.bpm, 4) : 0;

		for (section in data.song.notes)
		{
			if (section.changeBPM && offsetHolds)
			{
				stepCrochet = Timing.stepCrochet(section.bpm, 4);
			}

			for (note in section.sectionNotes)
			{
				final lane:Int = FNFLegacy.mustHitLane(section.mustHitSection, (note.lane + 4) % 8);
				final length:Float = note.length > 0 ? note.length + stepCrochet : 0;
				final type:String = section.altAnim ? ALT_ANIM : resolveNoteType(note);

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

	override function getEvents():Array<BasicEvent>
	{
		var events:Array<BasicEvent> = [];
		var lastMustHit:Bool = FNFLegacy.FNF_LEGACY_DEFAULT_MUSTHIT;

		// Push musthit events
		forEachSection(data.song.notes, (section, startTime, endTime) ->
		{
			if (section.mustHitSection != lastMustHit)
			{
				events.push(FNFLegacy.makeMustHitSectionEvent(startTime, section.mustHitSection));
				lastMustHit = section.mustHitSection;
			}
		});

		return events;
	}

	function forEachSection(sections:Array<FNFLegacySection>, call:(FNFLegacySection, Float, Float) -> Void)
	{
		var time:Float = 0;
		var crochet = Timing.measureCrochet(data.song.bpm, 4);

		for (section in sections)
		{
			if (section.changeBPM)
			{
				var beats:Float = sectionBeats(section);
				crochet = Timing.measureCrochet(section.bpm, beats);
			}

			call(section, time, time + crochet);
			time += crochet;
		}
	}

	function sectionBeats(?section:FNFLegacySection):Float
	{
		return Std.int((section?.lengthInSteps ?? 16) / 4);
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		var time:Float = 0.0;
		var bpm:Float = data.song.bpm;
		var beats:Float = sectionBeats(data.song.notes[0]);
		var crochet:Float = Timing.measureCrochet(bpm, beats);

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
				crochet = Timing.measureCrochet(bpm, beats);
				bpmChanges.push({
					time: time,
					bpm: bpm,
					beatsPerMeasure: beats,
					stepsPerBeat: 4
				});
			}

			time += crochet;
		}

		Timing.sortBPMChanges(bpmChanges);

		return {
			title: data.song.song,
			bpmChanges: bpmChanges,
			offset: 0.0,
			scrollSpeeds: [diffs[0] => data.song.speed],
			extraData: [
				PLAYER_1 => data.song.player1,
				PLAYER_2 => data.song.player2,
				NEEDS_VOICES => data.song.needsVoices,
				LANES_LENGTH => 8
			]
		}
	}

	override function stringify(?chartFormatting:String, ?metaFormatting:String)
	{
		return {
			data: Json.stringify(data, chartFormatting),
			meta: Json.stringify(meta, metaFormatting)
		}
	}

	public override function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):FNFLegacyBasic<T>
	{
		return fromJson(Util.getText(path), meta != null ? Util.getText(meta) : meta, diff);
	}

	public function fromJson(data:String, ?meta:String, ?diff:FormatDifficulty):FNFLegacyBasic<T>
	{
		this.diffs = diff;
		this.data = Json.parse(fixLegacyJson(data));
		return this;
	}

	// Old json charts were hyper fucked with corrupted data
	function fixLegacyJson(rawJson:String):String
	{
		var split = rawJson.split("}");
		var pop = split.length - 1;

		if (split[pop].length > 0)
			split[pop] = "";

		rawJson = split.join("}");

		return rawJson;
	}
}
