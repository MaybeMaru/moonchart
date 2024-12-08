package moonchart.backend;

import moonchart.backend.Util;
import moonchart.formats.BasicFormat;

class Timing
{
	public static function sortTiming<T:BasicTimingObject>(objects:Array<T>):Array<T>
	{
		objects.sort((a, b) -> Util.sortValues(a.time, b.time));
		return objects;
	}

	public static inline function sortNotes(notes:Array<BasicNote>):Array<BasicNote>
	{
		return sortTiming(notes);
	}

	public static inline function sortEvents(events:Array<BasicEvent>):Array<BasicEvent>
	{
		return sortTiming(events);
	}

	public static inline function sortBPMChanges(bpmChanges:Array<BasicBPMChange>):Array<BasicBPMChange>
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

	public static inline function crochet(bpm:Float):Float
	{
		return (60 / bpm) * 1000;
	}

	public static inline function stepCrochet(bpm:Float, stepsPerBeat:Float):Float
	{
		return crochet(bpm) / stepsPerBeat;
	}

	public static inline function measureCrochet(bpm:Float, beatsPerMeasure:Float):Float
	{
		return crochet(bpm) * beatsPerMeasure;
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

		var endTime:Float = 0.0;
		var curTime:Float = 0.0;

		if (notes.length > 0)
		{
			var lastNote = notes[notes.length - 1];
			endTime = Math.max(lastNote.time + lastNote.length, endTime);
		}

		if (events.length > 0)
		{
			endTime = Math.max(events[events.length - 1].time, endTime);
		}

		if (bpmChanges.length > 0)
		{
			endTime = Math.max(bpmChanges[bpmChanges.length - 1].time, endTime);
		}

		var measures:Array<BasicMeasure> = [];
		var noteIndex:Int = 0;
		var eventIndex:Int = 0;

		var lastChange:BasicBPMChange = bpmChanges[0];
		var crochet:Float = measureCrochet(lastChange.bpm, lastChange.beatsPerMeasure);
		var bpmIndex:Int = 0;

		while (curTime < endTime)
		{
			var measureNotes:Array<BasicNote> = [];
			var measureEvents:Array<BasicEvent> = [];
			var measureBpmChanges:Array<BasicBPMChange> = [];
			var endTime:Float = curTime + crochet;

			var measure:BasicMeasure = {
				notes: measureNotes,
				events: measureEvents,
				bpmChanges: measureBpmChanges,
				bpm: lastChange.bpm,
				beatsPerMeasure: lastChange.beatsPerMeasure,
				stepsPerBeat: lastChange.stepsPerBeat,
				startTime: curTime,
				endTime: endTime,
				length: crochet,
				snap: 0
			}

			// Add notes to the current measure
			while (noteIndex < notes.length && (notes[noteIndex].time + 1) < endTime)
				measureNotes.push(notes[noteIndex++]);

			// Add events to the current measure
			while (eventIndex < events.length && (events[eventIndex].time + 1) < endTime)
				measureEvents.push(events[eventIndex++]);

			// Calculate snap and push measure
			measure.snap = findMeasureSnap(measure);
			measures.push(measure);

			// Advance time to the next measure
			curTime += crochet;

			// Run through all bpm changes that happened in the measure
			// TODO: i think i should account for the elapsed time between bpm changes?
			while (bpmIndex < bpmChanges.length && (bpmChanges[bpmIndex].time) <= curTime)
			{
				lastChange = bpmChanges[bpmIndex++];
				measureBpmChanges.push(lastChange);
				crochet = measureCrochet(lastChange.bpm, lastChange.beatsPerMeasure);
			}
		}

		return measures;
	}

	public static final snaps:Array<Int8> = [4, 8, 12, 16, 24, 32, 48, 64, 192];

	public static function getSnapBeat(snap:Int8):Float
	{
		return switch (snap)
		{
			case 4: 1;
			case 8: 1 / 2;
			case 12: 1 / 3;
			case 16: 1 / 4;
			case 24: 1 / 6;
			case 32: 1 / 8;
			case 48: 1 / 12;
			case 64: 1 / 16;
			default: 1 / 48; // 192
		}
	}

	public static inline function snapTime(time:Float, startTime:Float, duration:Float, snap:Int8):Int
	{
		return Math.round((time - startTime) / duration * snap);
	}

	public static inline function snapTimeMeasure(time:Float, measure:BasicMeasure, snap:Int8):Int
	{
		return snapTime(time, measure.startTime, measure.length, snap);
	}

	public static function findMeasureSnap(measure:BasicMeasure):Int8
	{
		final measureDuration:Float = measure.length;
		final measureTime:Float = measure.startTime;
		final measureEnd:Float = measure.endTime;

		var curSnap:Int8 = snaps[0];
		var maxSnap:Float = Math.POSITIVE_INFINITY;

		for (snap in snaps)
		{
			var snapScore:Float = 0;

			for (note in measure.notes)
			{
				// Calculate note snap
				var noteTime = Math.min(note.time - measureTime, measureDuration);
				var aproxPos = (noteTime / measureDuration) * snap;
				var snapPos = Math.round(aproxPos);
				snapScore += Math.abs(snapPos - aproxPos);

				// Calculate hold snap too
				if (note.length > 0)
				{
					var holdTime = (note.time + note.length) - measureTime;
					if (holdTime <= measureDuration)
					{
						var aproxPos = (holdTime / measureDuration) * snap;
						var snapPos = Math.round(aproxPos);
						snapScore += Math.abs(snapPos - aproxPos);
					}
				}
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
