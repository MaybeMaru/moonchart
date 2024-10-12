package moonchart.formats.fnf;

import moonchart.backend.FormatData;
import haxe.Json;
import moonchart.backend.Timing;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.parsers._internal.BitmapFile;

using StringTools;

typedef FNFLudumDareMeta =
{
	song:String,
	bpm:Int,
	sections:Int
}

typedef FNFLudumDareFormat =
{
	var sections:Array<Array<Int>>;
}

class FNFLudumDare extends BasicFormat<FNFLudumDareFormat, FNFLudumDareMeta>
{
	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_LUDUM_DARE,
			name: "FNF (Ludum Dare)",
			description: "This was a mistake.",
			extension: "folder::png",
			hasMetaFile: TRUE,
			metaFileExtension: "json",
			handler: FNFLudumDare
		}
	}

	public function new(?data:FNFLudumDareFormat)
	{
		super({timeFormat: STEPS, supportsDiffs: false, supportsEvents: false});
		this.data = data;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFLudumDare
	{
		var chartResolve = resolveDiffsNotes(chart, diff);
		var diffChart:Array<BasicNote> = chartResolve.notes.get(chartResolve.diffs[0]);
		var measures = Timing.divideNotesToMeasures(diffChart, [], [chart.meta.bpmChanges[0]]);

		var index:Int = 0;
		var sections:Array<Array<Int>> = [];
		for (measure in measures)
		{
			if (index % 2 == 0)
			{
				var snap = measure.snap;
				var section:Array<Int> = [];
				for (i in 0...snap)
					section.push(0);

				for (note in measure.notes)
				{
					// I have no fucking clue man
					var lane:Int = switch (note.lane % 4)
					{
						case 3: 2;
						case 2: 1;
						case 1: 3;
						case _: 4;
					}

					var step = Timing.snapTimeMeasure(note.time, measure, snap);
					if (section[step] == 0)
					{
						section[step] = lane;

						if (note.length > 0)
						{
							var holdSteps = Timing.snapTimeMeasure(note.time + note.length, measure, snap) - step;
							for (i in 0...holdSteps)
							{
								var index = step + 1 + i;
								if (section[index] == 0)
								{
									section[index] = -lane;
								}
							}
						}
					}
				}

				sections.push(section);
			}

			index++;
		}

		this.data = {
			sections: sections
		}

		this.meta = {
			song: chart.meta.title,
			bpm: Std.int(chart.meta.bpmChanges[0].bpm),
			sections: sections.length
		}

		return this;
	}

	override function getNotes(?diff:String):Array<BasicNote>
	{
		var notes:Array<BasicNote> = [];

		var crochet = Timing.crochet(meta.bpm);
		var stepCrochet = crochet / 4;

		for (i in 0...2)
		{
			var isPlayer = i == 1;
			var beat:Int = 0;
			var totalLength:Int = 0;

			for (section in data.sections)
			{
				var step:Int = 0;
				var sectionBeats:Int = Std.int(section.length / 4);

				if (sectionBeats <= 4)
				{
					sectionBeats = 4;
				}
				else if (sectionBeats <= 8)
				{
					sectionBeats = 8;
				}

				var lastNote:BasicNote = null;

				for (data in section)
				{
					if (data != 0)
					{
						var isHold = data < 0;
						var time:Float = ((step * stepCrochet) + (crochet * 8 * totalLength)) + ((crochet * sectionBeats) * i);

						var lane:Int = switch (Math.abs(data))
						{
							case 1: 2;
							case 2: 3;
							case 3: 1;
							case _: 0;
						}

						if (!isHold)
						{
							if (!isPlayer)
							{
								lane += 4;
							}

							var note:BasicNote = {
								time: time,
								lane: lane,
								length: 0,
								type: ""
							}

							notes.push(note);
							lastNote = note;
						}
						else if (lastNote != null)
						{
							// Push note length
							lastNote.length = time - lastNote.time;
						}
					}

					step++;
				}

				totalLength += Math.round(sectionBeats / 4);
				beat++;
			}
		}

		Timing.sortNotes(notes);
		return notes;
	}

	override function getEvents():Array<BasicEvent>
	{
		var events:Array<BasicEvent> = [];

		var crochet = ((60 / meta.bpm) * 1000);
		var stepCrochet = crochet / 4;

		for (i in 0...2)
		{
			var isPlayer = i == 1;
			var beat:Int = 0;
			var totalLength:Int = 0;

			for (section in data.sections)
			{
				var step:Int = 0;
				var sectionBeats:Int = Std.int(section.length / 4);

				if (sectionBeats <= 4)
				{
					sectionBeats = 4;
				}
				else if (sectionBeats <= 8)
				{
					sectionBeats = 8;
				}

				var startTime:Float = ((step * stepCrochet) + (crochet * 8 * totalLength)) + ((crochet * sectionBeats) * i);
				events.push(FNFLegacy.makeMustHitSectionEvent(startTime, isPlayer));
				step += section.length;

				totalLength += Math.round(sectionBeats / 4);
				beat++;
			}
		}

		events = Timing.sortEvents(events);

		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		return {
			title: meta.song,
			offset: 0.0,
			scrollSpeeds: Util.fillMap(diffs, 1.0),
			bpmChanges: [
				{
					time: 0,
					bpm: meta.bpm,
					beatsPerMeasure: 4,
					stepsPerBeat: 4
				}
			],
			extraData: [LANES_LENGTH => 8]
		}
	}

	inline function formatSection(song:String, index:Int):String
	{
		return song.toLowerCase() + "_section" + (index + 1) + ".png";
	}

	override function fromFile(path:String, ?meta:String, ?diff:FormatDifficulty):FNFLudumDare
	{
		return fromFolder(path, diff);
	}

	public function fromFolder(path:String, ?diff:FormatDifficulty):FNFLudumDare
	{
		var files = Util.readFolder(path);
		this.diffs = diff;

		if (!path.endsWith("/"))
			path += "/";

		for (file in files)
		{
			if (file.endsWith("json"))
			{
				this.meta = Json.parse(Util.getText(path + file));
				break;
			}
		}

		var decodedSections:Array<Array<Int>> = [];
		var bitmap = new moonchart.parsers._internal.BitmapFile();

		for (i in 0...meta.sections)
		{
			bitmap.fromFile(path + formatSection(meta.song, i));
			decodedSections.push(decodeSection(bitmap.toCSV()));
		}

		this.data = {
			sections: decodedSections
		}

		return this;
	}

	override function stringify(?_, ?metaFormatting:String):{data:Null<String>, meta:Null<String>}
	{
		return {
			data: "",
			meta: Json.stringify(meta, metaFormatting)
		}
	}

	// Ludum Dare encode / decode fuckery

	public function encodeSections(destPath:String)
	{
		for (i in 0...data.sections.length)
			encodeSection(i, destPath);
	}

	public function encodeSection(index:Int, destPath:String)
	{
		if (!destPath.endsWith("/"))
			destPath += "/";

		var section = data.sections[index];
		if (section == null)
			return;

		var bmd = new BitmapFile().make(8, section.length, 0xFFFFFFFF);

		for (y in 0...section.length)
		{
			var x = section[y];
			if (x != 0)
			{
				if (x < 0)
					x = Std.int(Math.abs(x)) + 4;

				bmd.setPixel(x - 1, y, 0xFF000000);
			}
		}

		bmd.savePNG(destPath + formatSection(meta.song, index));
	}

	function decodeSection(csv:String)
	{
		var regex:EReg = new EReg("[ \t]*((\r\n)|\r|\n)[ \t]*", "g");

		var lines:Array<String> = regex.split(csv);
		var rows:Array<String> = lines.filter((line) -> return line != "");
		csv.replace("\n", ',');

		var heightInTiles = rows.length;
		var widthInTiles = 0;

		var row:Int = 0;

		// LMAOOOO STOLE ALL THIS FROM FLXBASETILEMAP LOLOL
		// LMAOOOO STOLE ALL THIS FROM LUDUM DARE PROTOTYPE LOLOL

		var dopeArray:Array<Int> = [];
		while (row < heightInTiles)
		{
			var rowString = rows[row];
			if (rowString.endsWith(","))
			{
				rowString = rowString.substr(0, rowString.length - 1);
			}

			var columns = rowString.split(",");

			if (columns.length == 0)
			{
				heightInTiles--;
				continue;
			}

			if (widthInTiles == 0)
				widthInTiles = columns.length;

			var column = 0;
			var pushedInColumn:Bool = false;
			while (column < widthInTiles)
			{
				var columnString = columns[column];
				var curTile = Std.parseInt(columnString);

				if (curTile == 1)
				{
					if (column < 4)
						dopeArray.push(column + 1);
					else
					{
						var tempCol = (column + 1) * -1;
						tempCol += 4;
						dopeArray.push(tempCol);
					}

					pushedInColumn = true;
				}

				column++;
			}

			if (!pushedInColumn)
				dopeArray.push(0);

			row++;
		}

		return dopeArray;
	}
}
