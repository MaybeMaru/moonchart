package moonchart.formats;

import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.parsers.OsuParser;

using StringTools;

class OsuMania extends BasicFormat<OsuFormat, {}>
{
	// OSU Constants
	public static inline var OSU_SCROLL_SPEED:Float = 0.675;
	public static inline var OSU_CIRCLE_SIZE:Int = 512;

	var parser:OsuParser;

	public function new(?data:OsuFormat)
	{
		super({timeFormat: MILLISECONDS, supportsDiffs: false, supportsEvents: true});
		parser = new OsuParser();

		this.data = data;
		if (data != null)
			this.diffs = data.Metadata.Version;
	}

	// TODO: finish the rest of the converter proccess
	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):OsuMania
	{
		var chartResolve = resolveDiffsNotes(chart, diff);
		var diff:String = chartResolve.diffs[0];
		var basicNotes:Array<BasicNote> = chartResolve.notes.get(diff);

		var hitObjects:Array<Array<Int>> = [];
		for (note in basicNotes)
		{
			var lane = Std.int((note.lane * OSU_CIRCLE_SIZE) / (4)); // TODO: Add extra keys here later
			var time = Std.int(note.time);
			var length = time + (Std.int(note.length));

			// TODO: gotta figure out what these other shits do
			hitObjects.push([lane, 0, time, 0, 0, length]);
		}

		var timingPoints:Array<Array<Float>> = [];
		for (change in chart.meta.bpmChanges)
		{
			timingPoints.push([Std.int(change.time), Timing.crochet(change.bpm), 4, 1, 0, 0, 1, 0]);
		}

		/*var events:Array<Array<Dynamic>> = [];
			for (event in chart.data.events)
			{
				if (event.name == "OSU_EVENT")
				{
					events.push([]);
				}
		}*/

		var sliderMult:Float = chart.meta.scrollSpeeds.get(diff) ?? 1.0;
		sliderMult *= OSU_SCROLL_SPEED;

		this.data = {
			format: "osu file format v14",
			General: {
				AudioFilename: "",
				AudioLeadIn: Std.int(chart.meta.offset ?? 0),
				PreviewTime: -1,
				Countdown: 1,
				SampleSet: "Normal",
				StackLeniency: 0.7,
				Mode: 3,
				LetterboxInBreaks: 0,
				SpecialStyle: 0,
				WidescreenStoryboard: 0
			},
			// Editor: {},
			Metadata: {
				Title: chart.meta.title,
				TitleUnicode: chart.meta.title,
				Artist: chart.meta.extraData.get(SONG_ARTIST) ?? "Unknown",
				ArtistUnicode: "",
				Creator: chart.meta.extraData.get(SONG_CHARTER) ?? "Unknown",
				Version: diff,
				Source: "",
				BeatmapID: 0,
				BeatmapSetID: 0
			},
			Difficulty: {
				HPDrainRate: 0,
				CircleSize: 4, // TODO: later support extra keys
				OverallDifficulty: 0,
				ApproachRate: 0,
				SliderMultiplier: sliderMult,
				SliderTickRate: 0,
			},
			// Events: events,
			TimingPoints: timingPoints,
			HitObjects: hitObjects,
		}

		return this;
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var circleSize:Int = data.Difficulty.CircleSize;

		for (note in data.HitObjects)
		{
			var time = note[2];
			var lane = Math.floor(note[0] * circleSize / OSU_CIRCLE_SIZE);
			var length = (note[5] > 0) ? (note[5] - time) : 0;

			notes.push({
				time: time,
				lane: lane,
				length: length,
				type: ""
			});
		}

		Timing.sortNotes(notes);

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

		// Pushing the first bpm change at 0 for good measure
		bpmChanges.push({
			time: 0,
			bpm: Timing.crochet(data.TimingPoints[0][1]),
			beatsPerMeasure: 4,
			stepsPerBeat: 4
		});

		for (point in data.TimingPoints)
		{
			// ugly scroll speed change shit TODO: maybe implement it as an event
			if (point[6] == 0)
				continue;

			var time = point[0];
			var bpm = Timing.crochet(point[1]);
			bpmChanges.push({
				time: time,
				bpm: bpm,
				beatsPerMeasure: 4,
				stepsPerBeat: 4
			});
		}

		// TODO: im not quite sure if this is correct, double check
		var osuSpeed:Float = data.Difficulty.SliderMultiplier / OSU_SCROLL_SPEED;

		return {
			title: data.Metadata.Title,
			bpmChanges: bpmChanges,
			offset: data.General.AudioLeadIn,
			scrollSpeeds: [diffs[0] => osuSpeed],
			extraData: [SONG_ARTIST => data.Metadata.Artist, SONG_CHARTER => data.Metadata.Creator]
		}
	}

	override function stringify()
	{
		return {
			data: parser.stringify(data),
			meta: null
		}
	}

	override public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):OsuMania
	{
		return fromOsu(Util.getText(path), diff);
	}

	public function fromOsu(data:String, ?diff:FormatDifficulty):OsuMania
	{
		this.data = parser.parse(data);
		this.diffs = diff ?? this.data.Metadata.Version;

		var mode:Int = this.data.General.Mode;
		if (mode != 3)
		{
			var osuMode:String = switch (mode)
			{
				case 0: "osu!";
				case 1: "osu!taiko";
				case 2: "osu!catch";
				case _: "[NOT FOUND]";
			}
			throw 'Osu game mode $osuMode is not supported.';
			return null;
		}

		return this;
	}
}
