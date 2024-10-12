package moonchart.formats;

import moonchart.backend.FormatData;
import moonchart.parsers.BasicParser;
import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.parsers.StepManiaParser;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.formats.BasicFormat.BasicNoteType;

enum abstract StepManiaNote(String) from String to String
{
	var EMPTY = "0";
	var NOTE = "1";
	var HOLD_HEAD = "2";
	var HOLD_TAIL = "3";
	var ROLL_HEAD = "4";
	var MINE = "M";
}

class StepMania extends StepManiaBasic<StepManiaFormat>
{
	// StepMania Constants
	public static inline var STEPMANIA_SCROLL_SPEED:Float = 0.017775; // 0.00355555555;

	public static function __getFormat():FormatData
	{
		return {
			ID: STEPMANIA,
			name: "StepMania",
			description: "",
			extension: "sm",
			hasMetaFile: FALSE,
			handler: StepMania
		}
	}

	public function new(?data:StepManiaFormat)
	{
		super(data);
		parser = new StepManiaParser();
	}

	override public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):StepMania
	{
		return fromStepMania(Util.getText(path), diff);
	}

	public function fromStepMania(data:String, ?diff:FormatDifficulty):StepMania
	{
		this.data = cast parser.parse(data);
		this.diffs = diff ?? Util.mapKeyArray(this.data.NOTES);
		return this;
	}
}

@:private
@:noCompletion
class StepManiaBasic<T:StepManiaFormat> extends BasicFormat<T, {}>
{
	var parser:BasicParser<T>;

	public function new(?data:T)
	{
		super({timeFormat: STEPS, supportsDiffs: true, supportsEvents: true});
		this.data = data;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):StepManiaBasic<T>
	{
		var basicData = resolveDiffsNotes(chart, diff);
		var bpmChanges = chart.meta.bpmChanges;

		var smNotes:Map<String, StepManiaNotes> = [];

		for (diff => basicNotes in basicData.notes)
		{
			// Find dance
			final lanes:Int = chart.meta.extraData.get(LANES_LENGTH) ?? 4;
			final dance:StepManiaDance = (lanes >= 8) ? DOUBLE : resolveDance(basicNotes);
			final songStep:StepManiaStep = (dance == DOUBLE) ? [EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY, EMPTY] : [EMPTY, EMPTY, EMPTY, EMPTY];

			// Divide notes to measures
			var basicMeasures = Timing.divideNotesToMeasures(basicNotes, [], bpmChanges);
			var measures:Array<StepManiaMeasure> = [];
			var nextMeasureNotes:Array<BasicNote> = [];

			// Snap measures
			for (basicMeasure in basicMeasures)
			{
				var measure:StepManiaMeasure = new StepManiaMeasure();
				var snap = basicMeasure.snap;

				// Prepare each step of the measure
				for (i in 0...snap)
				{
					measure.push(songStep.copy());
				}

				// Find notes of the current measure
				var measureNotes:Array<BasicNote>;
				if (nextMeasureNotes.length > 0)
				{
					measureNotes = basicMeasure.notes.concat(nextMeasureNotes);
					nextMeasureNotes.resize(0);
				}
				else
				{
					measureNotes = basicMeasure.notes;
				}

				// Add notes to the measure's steps
				for (note in measureNotes)
				{
					var noteStep:Int = Timing.snapTimeMeasure(note.time, basicMeasure, snap);

					if (noteStep > measure.length - 1)
					{
						// Save notes out of the measure for the next one
						nextMeasureNotes.push(note);
						continue;
					}
					else if (noteStep < 0)
					{
						// We shouldnt need to check for this, look further into it later
						continue;
					}

					// Normal note
					if (note.length <= 0)
					{
						measure[noteStep][note.lane] = switch (note.type)
						{
							case BasicNoteType.MINE: MINE;
							default: NOTE;
						}
					}
					// Hold note
					else
					{
						var holdStep:Int = Timing.snapTimeMeasure(note.time + note.length, basicMeasure, snap);
						holdStep = Util.minInt(holdStep, measure.length - 1);

						if (holdStep <= noteStep)
							continue;

						measure[noteStep][note.lane] = switch (note.type)
						{
							case BasicNoteType.ROLL: ROLL_HEAD;
							default: HOLD_HEAD;
						}

						measure[holdStep][note.lane] = HOLD_TAIL;
					}
				}

				measures.push(measure);
			}

			smNotes.set(diff, {
				diff: diff,
				desc: "",
				dance: dance,
				notes: measures,
				charter: chart.meta.extraData.get(SONG_CHARTER) ?? "Unknown",
				meter: 1,
				radar: [0, 0, 0, 0, 0]
			});
		}

		// Convert BPM milliseconds to beats
		var beats:Float = 0;
		var prevTime:Float = 0;

		var prevBpm:Float = bpmChanges[0].bpm;
		var bpms:Array<StepManiaBPM> = [];

		bpms.push({
			beat: 0,
			bpm: prevBpm
		});

		for (i in 1...bpmChanges.length)
		{
			final change = bpmChanges[i];
			beats += ((change.time - prevTime) / 60000) * prevBpm;

			bpms.push({
				beat: beats,
				bpm: change.bpm
			});

			prevTime = change.time;
			prevBpm = change.bpm;
		}

		this.data = cast {
			TITLE: chart.meta.title,
			ARTIST: chart.meta.extraData.get(SONG_ARTIST) ?? "Unknown",
			OFFSET: (chart.meta.offset ?? 0.0) / 1000,
			BPMS: bpms,
			NOTES: smNotes
		}

		return this;
	}

	function resolveDance(notes:Array<BasicNote>):StepManiaDance
	{
		for (note in notes)
		{
			if (note.lane > 3)
			{
				return DOUBLE;
			}
		}
		return SINGLE;
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var smChart = data.NOTES.get(diff);
		if (smChart == null)
		{
			throw "Couldn't find StepMania notes for difficulty " + diff;
			return null;
		}

		var smNotes = smChart.notes;
		var notes:Array<BasicNote> = [];

		// Just easier for me if its in milliseconds lol
		var bpmChanges = getChartMeta().bpmChanges;
		var bpmIndex:Int = 1;

		var bpm = bpmChanges[0].bpm;
		var time:Float = 0;

		final getCrochet = (snap:Int) -> return Timing.snappedStepCrochet(bpm, 4, snap);
		final holdIndexes:Array<Int> = (smChart.dance == DOUBLE) ? [-1, -1, -1, -1, -1, -1, -1, -1] : [-1, -1, -1, -1];

		for (measure in smNotes)
		{
			var crochet = getCrochet(measure.length);
			var s = 0;

			for (step in measure)
			{
				for (lane in 0...step.length)
				{
					switch (step[lane])
					{
						case EMPTY:
						case NOTE:
							notes.push({
								time: time,
								lane: lane,
								length: 0,
								type: ""
							});
						case MINE:
							notes.push({
								time: time,
								lane: lane,
								length: 0,
								type: BasicNoteType.MINE
							});
						case HOLD_HEAD:
							notes.push({
								time: time,
								lane: lane,
								length: crochet,
								type: ""
							});
							holdIndexes[lane] = notes.length - 1;
						case ROLL_HEAD:
							notes.push({
								time: time,
								lane: lane,
								length: crochet,
								type: BasicNoteType.ROLL
							});
							holdIndexes[lane] = notes.length - 1;
						case HOLD_TAIL:
							if (holdIndexes[lane] != -1)
							{
								notes[holdIndexes[lane]].length = time - notes[holdIndexes[lane]].time;
								holdIndexes[lane] = -1;
							}
						case _:
					}
				}

				time += crochet;
				s++;

				// Recalculate crochet on bpm changes
				while (bpmIndex < bpmChanges.length && time >= bpmChanges[bpmIndex].time)
				{
					bpm = bpmChanges[bpmIndex++].bpm;
					crochet = getCrochet(measure.length);
				}
			}
		}

		return notes;
	}

	// TODO
	override function getEvents():Array<BasicEvent>
	{
		return [];
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		var time:Float = 0;
		var lastBeat:Float = 0;
		var lastBPM:Float = data.BPMS[0].bpm;

		bpmChanges.push({
			time: 0,
			bpm: lastBPM,
			beatsPerMeasure: 4,
			stepsPerBeat: 4
		});

		// Convert the bpm changes from beats to milliseconds
		for (i in 1...data.BPMS.length)
		{
			var change = data.BPMS[i];
			time += ((change.beat - lastBeat) / lastBPM) * 60000;

			lastBeat = change.beat;
			lastBPM = change.bpm;

			bpmChanges.push({
				time: time,
				bpm: lastBPM,
				beatsPerMeasure: 4,
				stepsPerBeat: 4
			});
		}

		bpmChanges = Timing.sortBPMChanges(bpmChanges);

		// TODO: this may have to apply for bpm changes too, change scroll speed event?
		final speed:Float = bpmChanges[0].bpm * StepMania.STEPMANIA_SCROLL_SPEED;
		final offset:Float = data.OFFSET is String ? Std.parseFloat(cast data.OFFSET) : data.OFFSET;
		final isSingle:Bool = Util.mapFirst(data.NOTES).dance == SINGLE;

		return {
			title: data.TITLE,
			bpmChanges: bpmChanges,
			offset: offset * 1000,
			scrollSpeeds: Util.fillMap(diffs, speed),
			extraData: [SONG_ARTIST => data.ARTIST, LANES_LENGTH => isSingle ? 4 : 8]
		}
	}

	override function stringify(?_)
	{
		return {
			data: parser.stringify(data),
			meta: null
		}
	}
}
