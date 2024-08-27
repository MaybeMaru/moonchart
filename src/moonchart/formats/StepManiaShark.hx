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
		var events:Array<BasicEvent> = [];
		var bpmChanges = getChartMeta().bpmChanges;
		for (label in data.LABELS)
		{
			var change:BasicBPMChange = bpmChanges[0];
			for (idx in 0...bpmChanges.length)
			{
				if (bpmChanges[idx].beat <= label.beat)
				{
					change = bpmChanges[idx];
				}
				else
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
