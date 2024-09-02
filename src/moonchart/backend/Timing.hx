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

	public static function pushEndBpm(lastTimingObject:Dynamic, bpmChanges:Array<BasicBPMChange>)
	{
		if (lastTimingObject != null)
		{
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

	// TODO: adjust so notes at the start and end of measures get added correctly
	public static function divideNotesToMeasures(notes:Array<BasicNote>, events:Array<BasicEvent>, bpmChanges:Array<BasicBPMChange>):Array<BasicMeasure>
	{
		notes = sortNotes(notes.copy());
		events = sortEvents(events.copy());
		bpmChanges = sortBPMChanges(bpmChanges.copy());

		// Make sure theres a start bpm
		if (Std.int(bpmChanges[0].time) > 0)
		{
			bpmChanges.unshift({
				time: 0,
				bpm: bpmChanges[0].bpm,
				beatsPerMeasure: bpmChanges[0].beatsPerMeasure,
				stepsPerBeat: bpmChanges[0].stepsPerBeat
			});
		}

		if (notes.length > 0)
		{
			pushEndBpm(notes[notes.length - 1], bpmChanges);
		}

		if (events.length > 0)
		{
			pushEndBpm(events[events.length - 1], bpmChanges);
		}

		var firstChange = bpmChanges.shift();
		var lastTime:Float = firstChange.time;
		var lastBpm:Float = firstChange.bpm;

		var measures:Array<BasicMeasure> = [];

		for (event in bpmChanges)
		{
			var elapsed = event.time - lastTime;
			var crochet = measureCrochet(lastBpm, event.beatsPerMeasure);
			var elapsedMeasures = Math.floor(elapsed / crochet);

			for (_ in 0...elapsedMeasures)
			{
				var measure:BasicMeasure = {
					notes: [],
					events: [],
					bpm: event.bpm,
					beatsPerMeasure: event.beatsPerMeasure,
					stepsPerBeat: event.stepsPerBeat,
					startTime: lastTime,
					endTime: 0,
					length: 0,
					snap: 0
				}

				lastTime += crochet;
				measure.endTime = lastTime;
				measure.length = (measure.endTime - measure.startTime);

				while (notes.length > 0 && notes[0].time < lastTime)
				{
					measure.notes.push(notes.shift());
				}

				while (events.length > 0 && events[0].time < lastTime)
				{
					measure.events.push(events.shift());
				}

				// sortNotes(measure.notes);
				// sortEvents(measure.events);

				measure.snap = findMeasureSnap(measure);
				measures.push(measure);
			}

			lastBpm = event.bpm;
			lastTime = event.time;
		}

		// Add any lost notes or events in the process
		if (notes.length > 0 || events.length > 0)
		{
			var lastMeasure = measures[measures.length - 1];

			while (notes.length > 0)
				lastMeasure.notes.push(notes.shift());

			while (events.length > 0)
				lastMeasure.events.push(events.shift());
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
