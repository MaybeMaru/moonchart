package moonchart.formats;

import moonchart.formats.BasicFormat.BasicEvent;
import moonchart.formats.BasicFormat.BasicChart;
import haxe.io.Bytes;
import moonchart.formats.BasicFormat.FormatEncode;
import moonchart.formats.BasicFormat.BasicNote;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat.BasicBPMChange;
import moonchart.formats.BasicFormat.BasicMetaData;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat.FormatDifficulty;
import moonchart.parsers.MidiParser;
import moonchart.backend.FormatData;

typedef MidiTempoEvent =
{
	tick:Int,
	tempo:Int
}

/**
 * Still a WIP, VERY EXPERIMENTAL!!!
 * Wouldn't recommend using it yet
 * Needs a lotta work to actually be in a usable state
 */
class Midi extends BasicFormat<MidiFormat, {}>
{
	// MIDI Constants
	public static inline var MIDI_DEFAULT_DIVISION:Int = 96;

	public static function __getFormat():FormatData
	{
		return {
			ID: MIDI,
			name: "Midi",
			description: "Skrillex midi except played back in Windows 3.11",
			hasMetaFile: FALSE,
			extension: "mid",
			handler: Midi
		}
	}

	var parser:MidiParser;

	public function new(?data:MidiFormat)
	{
		super({
			timeFormat: TICKS,
			supportsDiffs: false,
			supportsEvents: true,
			isBinary: true
		});
		parser = new MidiParser();
		this.data = data;
	}

	// TODO:
	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):Midi
	{
		var chartResolve = resolveDiffsNotes(chart, diff);
		var diff:String = chartResolve.diffs[0];
		var basicNotes:Array<BasicNote> = chartResolve.notes.get(diff);
		var bpmChanges = chart.meta.bpmChanges;

		// Tempo MIDI Track
		var tempoTrack:MidiTrack = [];
		var tickCrochet:Float = 0.0;
		var lastTime:Float = 0.0;
		var lastTick:Int = 0;

		for (change in bpmChanges)
		{
			final elapsed = Math.max(change.time, 0) - lastTime;
			tickCrochet = Timing.stepCrochet(change.bpm, MIDI_DEFAULT_DIVISION);

			lastTick = Std.int(lastTick + (elapsed / tickCrochet));
			lastTime = change.time;

			tempoTrack.push(TEMPO_CHANGE(Std.int(change.bpm), lastTick));
			tempoTrack.push(TIME_SIGNATURE(4, 2, 24, 8, lastTick));
		}

		tempoTrack.push(END_TRACK(lastTick));

		// Notes MIDI Track
		var notesTrack:MidiTrack = [];
		notesTrack.push(TEXT(chart.meta.title, 0, TRACK_NAME_EVENT));

		final minTickLength:Float = MIDI_DEFAULT_DIVISION / 4;
		var tempoIndex:Int = 0;
		var lastNoteTick:Int = 0;

		lastTick = 0;
		lastTime = 0.0;

		for (note in basicNotes)
		{
			while (tempoIndex < bpmChanges.length && bpmChanges[0].time <= note.time)
			{
				final change = bpmChanges[tempoIndex++];
				final elapsed = Math.max(change.time, 0) - lastTime;
				tickCrochet = Timing.stepCrochet(change.bpm, MIDI_DEFAULT_DIVISION);

				lastTick = Std.int(lastTick + (elapsed / tickCrochet));
				lastTime = change.time;
			}

			final noteElapsed = (note.time - lastTime);
			final lane = 72 + note.lane;

			// Push start time of the note
			lastNoteTick = Std.int(lastTick + (noteElapsed / tickCrochet));
			notesTrack.push(MESSAGE([NOTE_ON, lane, 90], lastNoteTick));

			// Push end time of the note
			lastNoteTick += Std.int(Math.max(note.length / tickCrochet, minTickLength));
			notesTrack.push(MESSAGE([NOTE_OFF, lane, 90], lastNoteTick));
		}

		notesTrack.push(END_TRACK(lastNoteTick));

		this.data = {
			header: "MThd",
			headerLength: 6,
			format: 1,
			division: MIDI_DEFAULT_DIVISION,
			tracks: [tempoTrack, notesTrack]
		}

		return this;
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var tempoChanges = getTempoEvents();
		var tempoIndex:Int = 0;
		var crochet:Float = 0;

		var lastChangeTime:Float = 0;
		var lastChangeTick:Int = 0;

		var lastTick:Int = 0;
		final minTickLength:Float = data.division / 4;

		for (event in data.tracks[1])
		{
			switch (event)
			{
				case MESSAGE(byteArray, tick):
					var type:MidiMessageType = byteArray[0];
					switch (type)
					{
						case NOTE_ON:
							lastTick = tick;
							while (tempoIndex < tempoChanges.length && tick <= tempoChanges[tempoIndex].tick)
							{
								var change = tempoChanges[tempoIndex++];
								crochet = Timing.stepCrochet(change.tempo, data.division);
								lastChangeTime += (change.tick - lastChangeTick) * crochet;
								lastChangeTick = change.tick;
							}
						case NOTE_OFF:
							var time:Float = lastChangeTime + (lastTick - lastChangeTick) * crochet;
							var lane:Int = byteArray[1] % 8;

							var tickLength:Int = (tick - lastTick);
							var length:Float = tickLength > minTickLength ? (tickLength * crochet) : 0;

							notes.push({
								time: time,
								lane: lane,
								length: length,
								type: ""
							});
						default:
					}
				default:
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
		var lastTick:Int = 0;

		for (event in getTempoEvents())
		{
			var crochet = Timing.stepCrochet(event.tempo, data.division);
			time += (event.tick - lastTick) * crochet;
			lastTick = event.tick;

			bpmChanges.push({
				time: time,
				bpm: event.tempo,
				stepsPerBeat: 4,
				beatsPerMeasure: 4
			});
		}

		var title:String = "Unknown";

		for (event in data.tracks[1])
		{
			switch (event)
			{
				case TEXT(text, tick, type):
					if (type == TRACK_NAME_EVENT)
					{
						title = text;
						break;
					}
				default:
			}
		}

		return {
			title: title,
			bpmChanges: bpmChanges,
			scrollSpeeds: [],
			offset: 0,
			extraData: []
		}
	}

	function getTempoEvents():Array<MidiTempoEvent>
	{
		var events:Array<MidiTempoEvent> = [];

		for (event in data.tracks[0])
		{
			switch (event)
			{
				case TEMPO_CHANGE(tempo, tick):
					events.push({
						tick: tick,
						tempo: tempo
					});
				default:
			}
		}

		return events;
	}

	override function encode():FormatEncode
	{
		return {
			data: parser.encode(this.data),
			meta: null
		}
	}

	override function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):Midi
	{
		return fromBytes(Util.getBytes(path));
	}

	public function fromBytes(data:Bytes):Midi
	{
		this.data = parser.parseBytes(data);
		return this;
	}
}
