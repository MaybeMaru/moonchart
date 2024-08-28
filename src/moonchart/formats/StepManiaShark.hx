package moonchart.formats;

import moonchart.backend.Util;
import moonchart.backend.Timing;
import moonchart.formats.BasicFormat;
import moonchart.parsers.StepManiaSharkParser;
import moonchart.formats.StepMania.BasicStepMania;

// Extension of StepMania
class StepManiaShark extends BasicStepMania<SSCFormat>
{
	public function new(?data:SSCFormat)
	{
		super(data);
		this.data = data;
		parser = new StepManiaSharkParser();
	}

	// Mark labels as events cus that makes it usable for shit like FNF
	override function getEvents():Array<BasicEvent>
	{
		var events = super.getEvents();
		var bpmChanges = getChartMeta().bpmChanges;

		var lastTime:Float = 0;
		var lastBeat:Float = 0;
		var crochet:Float = Timing.crochet(bpmChanges.shift().bpm);

		for (label in data.LABELS)
		{
			var elapsedBeats = label.beat - lastBeat;
			var time = lastTime + (elapsedBeats * crochet);

			events.push({
				time: time,
				name: label.label,
				data: {}
			});

			lastTime = time;
			lastBeat = label.beat;

			// idk if this works with BPM Changes someone test this for me later -Neb
			// Not sure either lol someone test it pls -Maru
			while (bpmChanges.length > 0 && bpmChanges[0].time <= time)
			{
				crochet = Timing.crochet(bpmChanges.shift().bpm);
			}
		}

		return events;
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
