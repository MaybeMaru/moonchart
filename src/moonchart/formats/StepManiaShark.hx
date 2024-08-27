package moonchart.formats;

import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.parsers.StepManiaSharkParser;
import moonchart.parsers.StepManiaParser.StepManiaDance;
import moonchart.parsers.StepManiaParser.StepManiaBPM;
import moonchart.formats.StepMania.StepManiaNote;


// Just copied from StepMania

class StepManiaShark extends BasicFormat<SSCFormat, {}>
{
	// StepMania Constants
	public static inline var STEPMANIA_SCROLL_SPEED:Float = 0.017775; // 0.00355555555;
	public static inline var STEPMANIA_MINE:String = "STEPMANIA_MINE";
	public static inline var STEPMANIA_ROLL:String = "STEPMANIA_ROLL";

	var parser:StepManiaSharkParser;

	public function new(?data:SSCFormat)
	{
		super({timeFormat: STEPS, supportsDiffs: true, supportsEvents: true});
		this.data = data;
		parser = new StepManiaSharkParser();
	}

/* 	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):StepManiaShark
	{
        // TODO: implement
	} */

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

	// TODO: maybe make this crash-safe when notes arent found with a warning and returning empty arrays

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var smChart = data.NOTES.get(diff);
		if (smChart == null)
		{
			throw "Couldn't find StepMania notes for difficulty " + (diff ?? "null");
			return null;
		}

		var smNotes = smChart.notes;
		var notes:Array<BasicNote> = [];

		// Just easier for me if its in milliseconds lol
		var bpmChanges = getChartMeta().bpmChanges;

		var bpm = bpmChanges.shift().bpm;
		var time:Float = 0;

		final getCrochet = (snap:Int) -> return Timing.snappedStepCrochet(bpm, 4, snap);

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

	function findTailLength(lane:Int, step:Int, measure:SSCMeasure):Int
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

    // Mark labels as events cus that makes it usable for shit like FNF
	override function getEvents():Array<BasicEvent>
	{
        var events:Array<BasicEvent> = [];
		var bpmChanges = getChartMeta().bpmChanges;
        for(label in data.LABELS){
            var change:BasicBPMChange = bpmChanges[0];
            for (idx in 0...bpmChanges.length){
				if (bpmChanges[idx].beat <= label.beat){
					change = bpmChanges[idx];
                }else
                    break;
            }
            // idk if this works with BPM Changes someone test this for me later -Neb
            events.push({
				time: (change.time + (label.beat - change.beat) * Timing.crochet(change.bpm)),
                name: label.label,
                data: []
            });
        }

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		var time:Float = 0;
		var lastBeat:Float = 0;
		var lastBPM:Float = data.BPMS[0].bpm;

		bpmChanges.push({
			time: 0,
            beat: 0,
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
                beat: change.beat,
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

	override public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):StepManiaShark
	{
		return fromStepManiaShark(Util.getText(path), diff);
	}

	public function fromStepManiaShark(data:String, ?diff:FormatDifficulty):StepManiaShark
	{
		this.data = parser.parse(data);
		this.diffs = diff ?? Util.mapKeyArray(this.data.NOTES);
		return this;
	}
}
