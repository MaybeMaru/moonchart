package moonchart.formats;

import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.parsers.GuitarHeroParser;

typedef GhBpmChange =
{
	tick:Int,
	bpm:Float,
	beatsPerMeasure:Int,
	stepsPerBeat:Int
}

class GuitarHero extends BasicFormat<GuitarHeroFormat, {}>
{
	var parser:GuitarHeroParser;

	public function new(?data:GuitarHeroFormat)
	{
		super({timeFormat: TICKS, supportsEvents: true});
		this.data = data;
		parser = new GuitarHeroParser();
	}

	inline function getTick(lastTick:Int, diff:Float, tickCrochet:Float)
	{
		return Std.int(lastTick + (diff * tickCrochet));
	}

	// TODO: should add some metadata of the lanes length for this and the FNF formats
	// So the charts can actually load ingame lmao

	override function fromBasicFormat(chart:BasicChart, ?diff:String):GuitarHero
	{
		diff ??= this.diff;
		var basicNotes = Timing.sortNotes(Timing.resolveDiffNotes(chart, diff).copy());
		var bpmChanges = Timing.sortBPMChanges(chart.meta.bpmChanges.copy());

		// Push an end bpm for convenience
		Timing.pushEndBpm(basicNotes[basicNotes.length - 1], bpmChanges);

		var expertSingle:Array<GuitarHeroTimedObject> = [];
		var syncTrack:Array<GuitarHeroTimedObject> = [];

		var tickCrochet:Float = Timing.stepCrochet(bpmChanges[0].bpm, 192);
		var lastTime:Float = 0.0;
		var lastTick:Int = 0;

		for (change in bpmChanges)
		{
			var changeTick:Int = getTick(lastTick, change.time - lastTime, tickCrochet);

			var denExp:Int = Std.int(Math.log(change.stepsPerBeat) / Math.log(2));

			syncTrack.push({
				tick: changeTick,
				type: TIME_SIGNATURE_CHANGE,
				values: [change.beatsPerMeasure, denExp]
			});

			syncTrack.push({
				tick: changeTick,
				type: TEMPO_CHANGE,
				values: [Std.int(change.bpm * 1000)]
			});

			// Push notes between each bpm change
			while (basicNotes.length > 0 && basicNotes[0].time < change.time)
			{
				var note = basicNotes.shift();

				var tick:Int = getTick(lastTick, note.time - lastTime, tickCrochet);
				var length:Int = Std.int(note.length * tickCrochet);

				expertSingle.push({
					tick: tick,
					type: NOTE_EVENT,
					values: [note.lane, length]
				});
			}

			tickCrochet = Timing.stepCrochet(change.bpm, 192);
			lastTime = change.time;
			lastTick = changeTick;
		}

		var offset:Float = chart.meta.extraData.get(OFFSET) ?? 0;
		offset /= 1000;

		this.data = {
			Song: {
				Name: chart.meta.title,
				Resolution: 192, // Hardcoded to 192 atm because eh
				Offset: offset
			},
			SyncTrack: syncTrack,
			Events: [],
			ExpertSingle: expertSingle
		}

		return this;
	}

	override function getNotes():Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var tempoChanges:Array<GhBpmChange> = getTempoChanges();
		var res = data.Song.Resolution;

		var curChange:GhBpmChange = tempoChanges.shift();
		var initBpm:Float = curChange.bpm;
		var tickCrochet:Float = Timing.stepCrochet(initBpm, res);

		var lastChangeTick:Int = 0;
		var lastTime:Float = 0.0;
		var curTime:Float = 0.0;

		for (note in data.ExpertSingle)
		{
			if (note.type != NOTE_EVENT) // TODO: maybe could support lyric events later
				continue;

			if (tempoChanges.length > 0 && note.tick >= tempoChanges[0].tick)
			{
				curChange = tempoChanges.shift();
				lastChangeTick = curChange.tick;
				lastTime = curTime;

				tickCrochet = Timing.stepCrochet(curChange.bpm, res);
			}

			var time:Float = lastTime + ((note.tick - lastChangeTick) * tickCrochet);
			var lane:Int = note.values[0];
			var length:Float = note.values[1] * tickCrochet;

			notes.push({
				time: time,
				lane: lane,
				length: length,
				type: ""
			});

			curTime = time;
		}

		return notes;
	}

	// TODO: maybe add time signature too?
	function getTempoChanges():Array<GhBpmChange>
	{
		var tempoChanges:Array<GhBpmChange> = [];

		var beatsPerMeasure:Int = 4;
		var stepsPerBeat:Int = 4;

		for (event in data.SyncTrack)
		{
			switch (event.type)
			{
				case TIME_SIGNATURE_CHANGE:
					beatsPerMeasure = event.values[0];
					stepsPerBeat = Std.int(Math.pow(2, event.values[1] ?? 2));
				case TEMPO_CHANGE:
					tempoChanges.push({
						tick: event.tick,
						bpm: event.values[0] / 1000,
						beatsPerMeasure: beatsPerMeasure,
						stepsPerBeat: stepsPerBeat
					});
				case _:
			}
		}

		// Make sure its sorted
		tempoChanges.sort((tempo1, tempo2) -> return Util.sortValues(tempo1.tick, tempo2.tick));

		return tempoChanges;
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		// Get only the bpm change based events
		var tempoChanges:Array<GhBpmChange> = getTempoChanges();

		// Pushing the first bpm change at 0 for good measure
		var initBpm:Float = tempoChanges[0].bpm;
		var res = data.Song.Resolution;

		bpmChanges.push({
			time: 0,
			bpm: initBpm,
			beatsPerMeasure: tempoChanges[0].beatsPerMeasure,
			stepsPerBeat: tempoChanges[0].stepsPerBeat
		});

		var time:Float = 0;
		var tickCrochet = Timing.stepCrochet(initBpm, res);
		var lastTick:Int = 0;

		for (change in tempoChanges)
		{
			var elapsedTicks:Int = (change.tick - lastTick);
			var bpm:Float = change.bpm;
			time += elapsedTicks * tickCrochet;

			bpmChanges.push({
				time: time,
				bpm: bpm,
				beatsPerMeasure: change.beatsPerMeasure,
				stepsPerBeat: change.stepsPerBeat
			});

			lastTick = change.tick;
			tickCrochet = Timing.stepCrochet(bpm, res);
		}

		return {
			title: data.Song.Name,
			bpmChanges: bpmChanges,
			extraData: []
		}
	}

	override public function stringify()
	{
		return {
			data: parser.stringify(data),
			meta: null
		}
	}

	override public function fromFile(path:String, ?meta:String, ?diff:String):GuitarHero
	{
		return fromGuitarHero(Util.getText(path), diff);
	}

	public function fromGuitarHero(data:String, ?diff:String):GuitarHero
	{
		this.data = parser.parse(data);
		return this;
	}
}
