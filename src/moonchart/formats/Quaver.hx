package moonchart.formats;

import moonchart.backend.FormatData;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.parsers.QuaverParser;
import moonchart.parsers._internal.ZipFile;

using StringTools;

class Quaver extends BasicFormat<QuaverFormat, {}>
{
	public static final QUAVER_SLIDER_VELOCITY:String = "SLIDER_VELOCITY";

	public static function __getFormat():FormatData
	{
		return {
			ID: QUAVER,
			name: "Quaver",
			description: "",
			extension: "qua",
			packedExtension: "qp",
			hasMetaFile: FALSE,
			handler: Quaver
		}
	}

	var parser:QuaverParser;

	public function new(?data:QuaverFormat)
	{
		super({
			timeFormat: MILLISECONDS,
			supportsDiffs: false,
			supportsEvents: true,
			supportsPacks: true
		});
		this.data = data;
		parser = new QuaverParser();
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):Quaver
	{
		var chartResolve = resolveDiffsNotes(chart, diff);
		var chartDiff:String = chartResolve.diffs[0];
		var basicNotes:Array<BasicNote> = chartResolve.notes.get(chartDiff);

		var hitObjects:Array<QuaverHitObject> = [];
		for (note in basicNotes)
		{
			hitObjects.push({
				StartTime: Std.int(note.time),
				EndTime: note.length > 0 ? Std.int(note.length) : null,
				Lane: note.lane,
				KeySounds: [] // Too lazy to add support for these rn
			});
		}

		var timingPoints:Array<QuaverTimingPoint> = [];
		for (change in chart.meta.bpmChanges)
		{
			timingPoints.push({
				StartTime: Std.int(change.time),
				Bpm: change.bpm
			});
		}

		final extra = chart.meta.extraData;

		final keysMode:String = switch (extra.get(LANES_LENGTH) ?? 4)
		{
			case 4: "Keys4";
			case _: "Keys7";
		}

		this.data = {
			AudioFile: extra.get(AUDIO_FILE) ?? "audio.mp3",
			BackgroundFile: "''",
			MapId: 0,
			MapSetId: 0,
			Mode: keysMode,
			Artist: extra.get(SONG_ARTIST) ?? "Unknown",
			Source: "a",
			Tags: "a",
			Creator: extra.get(SONG_CHARTER) ?? "Unknown",
			Description: "a",
			BPMDoesNotAffectScrollVelocity: true,
			InitialScrollVelocity: chart.meta.scrollSpeeds.get(chartDiff) ?? 1.0,
			EditorLayers: [],
			CustomAudioSamples: [],
			SoundEffects: [],
			SliderVelocities: [],

			Title: chart.meta.title,
			TimingPoints: timingPoints,
			HitObjects: hitObjects,
			DifficultyName: chartDiff
		}

		return this;
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		for (hitObject in data.HitObjects)
		{
			final time:Int = (hitObject.StartTime ?? 0);
			final length:Int = (hitObject.EndTime != null) ? hitObject.EndTime - time : 0;

			notes.push({
				time: time,
				length: length,
				lane: hitObject.Lane - 1,
				type: ""
			});
		}

		return notes;
	}

	override function getEvents():Array<BasicEvent>
	{
		var events:Array<BasicEvent> = [];
		for (velocity in data.SliderVelocities)
		{
			events.push({
				time: (velocity.StartTime ?? 0),
				name: QUAVER_SLIDER_VELOCITY,
				data: {
					MULTIPLIER: velocity.Multiplier
				}
			});
		}
		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var bpmChanges:Array<BasicBPMChange> = [];

		for (timingPoint in data.TimingPoints)
		{
			bpmChanges.push({
				time: (timingPoint.StartTime ?? 0),
				bpm: timingPoint.Bpm,
				beatsPerMeasure: 4,
				stepsPerBeat: 4
			});
		}

		final lanesLength:Int = switch (data.Mode)
		{
			case "Keys4": 4;
			case _: 7;
		}

		return {
			title: data.Title,
			bpmChanges: bpmChanges,
			offset: 0.0,
			scrollSpeeds: [diffs[0] => data.InitialScrollVelocity],
			extraData: [
				LANES_LENGTH => lanesLength,
				AUDIO_FILE => data.AudioFile,
				SONG_ARTIST => data.Artist,
				SONG_CHARTER => data.Creator
			]
		}
	}

	override function stringify(?_, ?_)
	{
		return {
			data: parser.stringify(data),
			meta: null
		}
	}

	override public function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):Quaver
	{
		return fromQuaver(Util.getText(path), diff);
	}

	public function fromQuaver(data:String, ?diff:FormatDifficulty):Quaver
	{
		this.data = parser.parse(data);
		this.diffs = diff ?? this.data.DifficultyName;
		return this;
	}

	override public function fromPack(path:String, diff:FormatDifficulty):Quaver
	{
		var zip = new ZipFile().openFile(path);
		var chartEntries = zip.filterEntries((entry) -> return entry.fileName.endsWith(".qua"));
		var diffs = diff.resolve();

		for (entry in chartEntries)
		{
			var stringEntry = zip.unzipString(entry);
			var data = parser.parse(stringEntry);

			if (data.DifficultyName == diffs[0])
			{
				return fromQuaver(stringEntry);
				break;
			}
		}

		return this;
	}
}
