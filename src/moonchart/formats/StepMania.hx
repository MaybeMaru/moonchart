package moonchart.formats;

import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.parsers.StepManiaParser;

enum abstract StepManiaNote(String) from String to String
{
	var EMPTY = "0";
	var NOTE = "1";
	var HOLD_HEAD = "2";
	var HOLD_TAIL = "3";
	var ROLL_HEAD = "4";
	var MINE = "M";
}

class StepMania extends BasicFormat<StepManiaFormat, {}>
{
	// StepMania Constants
	public static inline var STEPMANIA_SCROLL_SPEED:Float = 0.017775; // 0.00355555555;
	public static inline var STEPMANIA_MINE:String = "STEPMANIA_MINE";
	public static inline var STEPMANIA_ROLL:String = "STEPMANIA_ROLL";

	var parser:StepManiaParser;

	public function new(?data:StepManiaFormat)
	{
		super({timeFormat: STEPS, supportsDiffs: true, supportsEvents: true});
		this.data = data;
		parser = new StepManiaParser();
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):StepMania
	{
		var basicData = resolveDiffsNotes(chart, diff);
		var bpmChanges = chart.meta.bpmChanges;

		var smNotes:Map<String, StepManiaNotes> = [];

		for (diff => basicNotes in basicData.notes)
		{
			// Find dance
			var dance:StepManiaDance = resolveDance(basicNotes);

			// Divide notes to measures
			var measures = new Array<StepManiaMeasure>();
			var basicMeasures = Timing.divideNotesToMeasures(basicNotes, [], bpmChanges);
			var nextMeasureNotes:Array<BasicNote> = [];

			// Snap measures
			for (basicMeasure in basicMeasures)
			{
				var measure:StepManiaMeasure = new StepManiaMeasure();
				var snap = basicMeasure.snap;

				for (i in 0...snap)
				{
					var step:StepManiaStep = [EMPTY, EMPTY, EMPTY, EMPTY];
					measure.push(dance == DOUBLE ? step.concat(step) : step);
				}

				var measureNotes = basicMeasure.notes.concat(nextMeasureNotes);
				nextMeasureNotes.resize(0);

				for (note in measureNotes)
				{
					var noteStep = Timing.snapTimeMeasure(note.time, basicMeasure, snap);

					if (noteStep > measure.length - 1)
					{
						// Save notes out of the measure for the next one
						nextMeasureNotes.push(note);
						continue;
					}

					// Normal note
					if (note.length <= 0)
					{
						measure[noteStep][note.lane] = switch (note.type)
						{
							case STEPMANIA_MINE: MINE;
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
							case STEPMANIA_ROLL: ROLL_HEAD;
							default: HOLD_HEAD;
						}

						measure[holdStep][note.lane] = HOLD_TAIL;
					}
				}

				measures.push(measure);
			}

			smNotes.set(diff, {
				diff: diff,
				dance: dance,
				notes: measures
			});
		}

		// Convert BPM milliseconds to beats
		var firstChange = bpmChanges.shift();
		var beats:Float = 0;
		var prevTime:Float = 0;
		var prevBpm:Float = firstChange.bpm;

		var bpms = new Array<StepManiaBPM>();

		bpms.push({
			beat: 0,
			bpm: prevBpm
		});

		for (change in bpmChanges)
		{
			beats += ((change.time - prevTime) / 60000) * prevBpm;

			bpms.push({
				beat: beats,
				bpm: change.bpm
			});

			prevTime = change.time;
			prevBpm = change.bpm;
		}

		this.data = {
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
		var smNotes = data.NOTES.get(diff).notes;
		var notes:Array<BasicNote> = [];

		// Just easier for me if its in milliseconds lol
		var bpmChanges = getChartMeta().bpmChanges;

		var bpm = bpmChanges.shift().bpm;
		var getCrochet = (snap:Int) ->
		{
			return Timing.snappedStepCrochet(bpm, 4, snap);
		}

		var time:Float = 0;

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
								type: STEPMANIA_MINE
							});
						case HOLD_HEAD:
							notes.push({
								time: time,
								lane: lane,
								length: findTailLength(lane, s, measure) * crochet,
								type: ""
							});
						case ROLL_HEAD:
							notes.push({
								time: time,
								lane: lane,
								length: findTailLength(lane, s, measure) * crochet,
								type: STEPMANIA_ROLL
							});
						case _:
					}
				}

				time += crochet;
				s++;

				// Recalculate crochet on bpm changes
				while (bpmChanges.length > 0 && time >= bpmChanges[0].time)
				{
					bpm = bpmChanges.shift().bpm;
					crochet = getCrochet(measure.length);
				}
			}
		}

		return notes;
	}

	function findTailLength(lane:Int, step:Int, measure:StepManiaMeasure):Int
	{
		var steps:Int = 0;
		for (i in step...measure.length)
		{
			if (measure[i][lane] == HOLD_TAIL)
			{
				break;
			}
			steps++;
		}
		return steps;
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
		var speed:Float = bpmChanges[0].bpm * STEPMANIA_SCROLL_SPEED;

		return {
			title: data.TITLE,
			bpmChanges: bpmChanges,
			offset: data.OFFSET * 1000,
			scrollSpeeds: Util.fillMap(diffs, speed),
			extraData: [SONG_ARTIST => data.ARTIST]
		}
	}

	override function stringify()
	{
		return {
			data: parser.stringify(data),
			meta: null
		}
	}

	override public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):StepMania
	{
		return fromStepMania(Util.getText(path), diff);
	}

	public function fromStepMania(data:String, ?diff:FormatDifficulty):StepMania
	{
		this.data = parser.parse(data);
		this.diffs = diff ?? Util.mapKeyArray(this.data.NOTES);
		return this;
	}
}
