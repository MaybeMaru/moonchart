package moonchart.backend;

import moonchart.formats.BasicFormat;
import moonchart.backend.Util;

class Timing
{
	public static function sortTiming<T:BasicTimingObject>(objects:Array<T>):Array<T>
	{
		objects.sort((object1, object2) -> return Util.sortValues(object1.time, object2.time));
		return objects;
	}

	public static function sortNotes(notes:Array<BasicNote>):Array<BasicNote>
	{
		return sortTiming(notes);
	}

	public static function sortEvents(events:Array<BasicEvent>):Array<BasicEvent>
	{
		return sortTiming(events);
	}

	public static function sortBPMChanges(bpmChanges:Array<BasicBPMChange>):Array<BasicBPMChange>
	{
		return sortTiming(bpmChanges);
	}

	/**
	 * Removes duplicate unnecesary bpm changes from a bpm array
	 * Checks for bpm and time signature changes	
	 */
	public static function cleanBPMChanges(bpmChanges:Array<BasicBPMChange>):Array<BasicBPMChange>
	{
		if (bpmChanges.length <= 1)
			return bpmChanges;

		var lastChange:BasicBPMChange = bpmChanges[0];

		for (i in 1...bpmChanges.length)
		{
			final newChange = bpmChanges[i];
			final bpm = Util.equalFloat(newChange.bpm, lastChange.bpm);
			final steps = Util.equalFloat(newChange.stepsPerBeat, lastChange.stepsPerBeat);
			final beats = Util.equalFloat(newChange.beatsPerMeasure, lastChange.beatsPerMeasure);

			if (bpm && steps && beats)
			{
				bpmChanges[i] = null;
				continue;
			}

			lastChange = newChange;
		}

		while (true)
		{
			final index:Int = bpmChanges.indexOf(null);
			if (index == -1)
				break;

			bpmChanges.splice(index, 1);
		}

		return bpmChanges;
	}

	public static function pushEndBpm(lastTimingObject:Dynamic, bpmChanges:Array<BasicBPMChange>)
	{
		if (lastTimingObject == null)
			return;

		var time = lastTimingObject.time;
		if (lastTimingObject.length != null)
		{
			time += lastTimingObject.length;
		}

		var lastBpmChange = bpmChanges[bpmChanges.length - 1];
		if (time > lastBpmChange.time)
		{
			bpmChanges.push({
				time: time,
				bpm: lastBpmChange.bpm,
				beatsPerMeasure: lastBpmChange.beatsPerMeasure,
				stepsPerBeat: lastBpmChange.stepsPerBeat
			});
		}
	}

	public static inline function crochet(bpm:Float):Float
	{
		return (60 / bpm) * 1000;
	}

	public static inline function stepCrochet(bpm:Float, stepsPerBeat:Float):Float
	{
		return crochet(bpm) / stepsPerBeat;
	}

	public static inline function measureCrochet(bpm:Float, beatsPerStep:Float):Float
	{
		return crochet(bpm) * beatsPerStep;
	}

	public static inline function snappedStepCrochet(bpm:Float, stepsPerBeat:Float, stepsPerMeasure:Float):Float
	{
		return crochet(bpm) * (stepsPerBeat / stepsPerMeasure);
	}

	public static function divideNotesToMeasures(notes:Array<BasicNote>, events:Array<BasicEvent>, bpmChanges:Array<BasicBPMChange>):Array<BasicMeasure>
	{
		notes = sortNotes(notes);
		events = sortEvents(events);
		bpmChanges = sortBPMChanges(bpmChanges.copy());

		// BPM setup crap
		pushEndBpm(notes[notes.length - 1], bpmChanges);
		pushEndBpm(events[events.length - 1], bpmChanges);

		var firstChange = bpmChanges[0];
		var lastTime:Float = firstChange.time;
		var lastBpm:Float = firstChange.bpm;

		// Add a BPM entry at time 0 if necessary
		if (Std.int(lastTime) > 0)
		{
			bpmChanges.unshift({
				time: 0,
				bpm: lastBpm,
				beatsPerMeasure: firstChange.beatsPerMeasure,
				stepsPerBeat: firstChange.stepsPerBeat
			});
		}

		var measures:Array<BasicMeasure> = [];
		var noteIndex:Int = 0;
		var eventIndex:Int = 0;

		for (bpmChange in bpmChanges)
		{
			var elapsed = bpmChange.time - lastTime;
			var crochet = measureCrochet(lastBpm, bpmChange.beatsPerMeasure);
			var remainingElapsed = elapsed;

			// Makes sure to create measures even for very small time intervals
			while (remainingElapsed > 0)
			{
				// Length of the measure in the remaining elapsed time
				var measureDuration = Math.min(remainingElapsed, crochet);

				var measure:BasicMeasure = {
					notes: [],
					events: [],
					bpm: bpmChange.bpm,
					beatsPerMeasure: bpmChange.beatsPerMeasure,
					stepsPerBeat: bpmChange.stepsPerBeat,
					startTime: lastTime,
					endTime: lastTime + measureDuration,
					length: measureDuration,
					snap: 0
				};

				// Add notes to the current measure
				while (noteIndex < notes.length && notes[noteIndex].time <= measure.endTime)
				{
					measure.notes.push(notes[noteIndex++]);
				}

				// Add events to the current measure
				while (eventIndex < events.length && events[eventIndex].time <= measure.endTime)
				{
					measure.events.push(events[eventIndex++]);
				}

				// Update the elapsed and remaining measure time
				lastTime += measureDuration;
				remainingElapsed -= measureDuration;

				// Calculate snap and push measure
				measure.snap = findMeasureSnap(measure);
				measures.push(measure);
			}

			// Update BPM for the next interval
			lastBpm = bpmChange.bpm;
			lastTime = bpmChange.time;
		}

		// Add any remaining notes or events to the last measure
		if (noteIndex < notes.length || eventIndex < events.length)
		{
			var lastMeasure = measures[measures.length - 1];

			while (noteIndex < notes.length)
			{
				lastMeasure.notes.push(notes[noteIndex++]);
			}

			while (eventIndex < events.length)
			{
				lastMeasure.events.push(events[eventIndex++]);
			}
		}

		return measures;
	}

	public static final snaps:Array<Int> = [4, 8, 12, 16, 24, 32, 48, 64, 192];

	public static inline function snapTimeMeasure(time:Float, measure:BasicMeasure, snap:Int)
	{
		return Math.round((time - measure.startTime) / measure.length * snap);
	}

	public static function findMeasureSnap(measure:BasicMeasure):Int
	{
		var curSnap:Int = snaps[0];
		var maxSnap:Float = Math.POSITIVE_INFINITY;
		var measureDuration:Float = measure.length;

		for (snap in snaps)
		{
			var snapScore:Float = 0;

			for (note in measure.notes)
			{
				var noteTime = Math.min((note.time - measure.startTime) + note.length, measureDuration);
				var aproxPos = noteTime / measureDuration * snap;
				var snapPos = Math.round(aproxPos);
				snapScore += Math.abs(snapPos - aproxPos);
			}

			if (snapScore < maxSnap)
			{
				maxSnap = snapScore;
				curSnap = snap;
			}
		}

		return curSnap;
	}
}
