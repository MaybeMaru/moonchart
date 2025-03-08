package moonchart.formats.fnf.legacy;

import haxe.Json;
import moonchart.backend.FormatData;
import moonchart.backend.Timing;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat;
import moonchart.formats.fnf.FNFGlobal.BasicFNFNoteType;
import moonchart.formats.fnf.FNFVSlice;
import moonchart.formats.fnf.legacy.FNFLegacy;

using StringTools;

enum abstract FNFFpsPlusNoteType(String) from String to String
{
	var FPS_PLUS_ALT_ANIM = "alt";
	var FPS_PLUS_CENSOR = "censor";
	var FPS_PLUS_HEY = "hey";
}

class FNFFpsPlus extends FNFLegacyBasic<FpsPlusJsonFormat>
{
	var events:FpsPlusEventsJson;
	var plusMeta:FpsPlusMetaJson;

	public static function __getFormat():FormatData
	{
		return {
			ID: FNF_LEGACY_FPS_PLUS,
			name: "FNF (FPS +)",
			description: "Similar to FNF Legacy but with some extra metadata.",
			extension: "json",
			formatFile: formatFile,
			hasMetaFile: POSSIBLE,
			metaFileExtension: "json",
			specialValues: ['"gf":'],
			findMeta: (files) ->
			{
				for (file in files)
				{
					if (Util.getText(file).contains("name"))
						return file;
				}
				return files[0];
			},
			handler: FNFFpsPlus
		}
	}

	public static function formatFile(title:String, diff:String):Array<String>
	{
		var legacy = FNFLegacy.formatFile(title, diff);
		legacy.push("meta");
		legacy.push("events");
		return legacy;
	}

	public function new(?data:FpsPlusJsonFormat)
	{
		super(data);
		this.formatMeta.supportsEvents = true;

		// Register FNF FPS+ note types
		noteTypeResolver.register(FNFFpsPlusNoteType.FPS_PLUS_HEY, BasicFNFNoteType.CHEER);
		noteTypeResolver.register(FNFFpsPlusNoteType.FPS_PLUS_ALT_ANIM, BasicFNFNoteType.ALT_ANIM);
		noteTypeResolver.register(FNFFpsPlusNoteType.FPS_PLUS_CENSOR, BasicFNFNoteType.CENSOR);
	}

	function resolveDifficulties(?ratings:Map<String, Int>, diffs:Array<String>)
	{
		for (i in 0...diffs.length)
			Util.setArray(diffs, i, diffs[i].trim().toLowerCase());

		// Sorted to the default FPS+ difficulties, for extra diffs you may need to check manually
		var sortedDiffs = Util.customSort(diffs, ["easy", "normal", "hard", "erect", "nightmare"]);
		var difficulties:Array<Int> = [];

		// Get song ratings from the diffs list, default to 0 if not found.
		for (diff in sortedDiffs)
			difficulties.push(ratings?.get(diff) ?? 0);

		return difficulties;
	}

	override function fromBasicFormat(chart:BasicChart, ?diff:FormatDifficulty):FNFFpsPlus
	{
		var basic = super.fromBasicFormat(chart, diff);
		this.data = basic.data;
		var extra = chart.meta.extraData;

		// Load metadata
		this.meta = this.plusMeta = {
			name: chart.meta.title,
			difficulties: resolveDifficulties(extra.get(SONG_RATINGS), Util.mapKeyArray(chart.data.diffs)),
			artist: extra.get(SONG_ARTIST) ?? Settings.DEFAULT_ARTIST,
			album: extra.get(SONG_ALBUM) ?? Settings.DEFAULT_ALBUM,
			compatableInsts: null,
			dadBeats: [0, 2],
			bfBeats: [1, 3],
			pauseMusic: "pause/breakfast",
			mixName: "Original",
		}

		// Load events
		var i:Int = 0;
		var basicEvents = chart.data.events;
		var events:Array<FpsPlusEvent> = Util.makeArray(basicEvents.length);
		this.events = makeFpsPlusEventsJson(events);

		// TODO: resolve input vslice events to work for FPS+
		if (basicEvents.length > 0)
		{
			var eventMeasures = Timing.divideNotesToMeasures([], basicEvents, chart.meta.bpmChanges);
			for (m in 0...eventMeasures.length)
			{
				for (basicEvent in eventMeasures[m].events)
				{
					// Add string values to the event name
					var name:String = basicEvent.name;
					var values = Util.resolveEventValues(basicEvent);
					if (values.length > 0)
						name += ";" + values.join(";");

					// FPS Plus events meta have the events section index for whatever reason
					var plusEvent:FpsPlusEvent = [m, basicEvent.time, 0, name];
					Util.setArray(events, i++, plusEvent);
				}
			}
		}

		// Other crap
		data.song.gf = extra.get(PLAYER_3) ?? "";
		data.song.stage = extra.get(STAGE) ?? "";

		return cast basic;
	}

	override function save(path:String, ?metaPath:StringInput)
	{
		var data = super.save(path, metaPath);

		var metaPath = data.metaPath;
		var split = metaPath.split("/");
		split.pop();
		split.push("events.json");

		var eventsPath = split.join("/");
		var stringify:FormatStringify = data.output;
		Util.saveText(eventsPath, stringify.meta.resolve()[1]);

		return data;
	}

	override function stringify():FormatStringify
	{
		var data = super.stringify();
		var metaArray = data.meta.resolve();
		metaArray.push(Json.stringify(events, formatting));
		data.meta = metaArray;
		return data;
	}

	override function getEvents():Array<BasicEvent>
	{
		var events = super.getEvents();

		for (plusEvent in this.events.events.events)
		{
			var time:Float = plusEvent.time;
			var values:Array<String> = plusEvent.name.split(";");
			var name:String = values.shift();

			events.push({
				time: time,
				name: name,
				data: {array: values}
			});
		}

		Timing.sortEvents(events);
		return events;
	}

	override function getChartMeta():BasicMetaData
	{
		var meta = super.getChartMeta();
		var extra = meta.extraData;

		var songRatings:Map<String, Int> = [];
		var ratings:Array<Int> = this.plusMeta?.difficulties ?? [];

		for (i => rating in ratings)
		{
			var diff = this.diffs[i] ?? Settings.DEFAULT_DIFF;
			songRatings.set(diff, rating);
		}

		extra.set(PLAYER_3, data.song.gf);
		extra.set(STAGE, data.song.stage);
		extra.set(SONG_RATINGS, songRatings);
		extra.set(SONG_ALBUM, plusMeta?.album ?? Settings.DEFAULT_ALBUM);
		return meta;
	}

	function makeFpsPlusEventsJson(events:Array<FpsPlusEvent>):FpsPlusEventsJson
	{
		return {
			events: {
				events: events
			}
		}
	}

	override function fromJson(data:String, ?meta:StringInput, ?diff:FormatDifficulty):FNFLegacyBasic<FpsPlusJsonFormat>
	{
		super.fromJson(data, meta, diff);
		final metaFiles:Array<String> = meta != null ? meta.resolve() : [];

		// Find and load the meta and events files from the meta input
		for (file in metaFiles)
		{
			var data:Dynamic = Json.parse(file);
			Reflect.hasField(data, "difficulties") ? this.plusMeta = data : this.events = data;
		}

		this.events ??= makeFpsPlusEventsJson([]);
		this.plusMeta ??= {
			name: Settings.DEFAULT_TITLE,
			difficulties: [0],
			artist: Settings.DEFAULT_ARTIST,
			album: Settings.DEFAULT_ARTIST,
			compatableInsts: null,
			dadBeats: [0, 2],
			bfBeats: [1, 3],
			pauseMusic: "pause/breakfast",
			mixName: "Original",
		}

		this.meta = this.plusMeta;
		return this;
	}
}

typedef FpsPlusJsonFormat = FNFLegacyFormat &
{
	stage:String,
	gf:String
}

typedef FpsPlusMetaJson =
{
	name:String,
	artist:String,
	album:String,
	difficulties:Array<Int>,
	compatableInsts:Null<Array<String>>,
	mixName:String,
	bfBeats:Array<Int>,
	dadBeats:Array<Int>,
	pauseMusic:String
}

typedef FpsPlusEventsJson =
{
	events:
	{
		events:Array<FpsPlusEvent>
	}
}

abstract FpsPlusEvent(Array<Dynamic>) from Array<Dynamic> to Array<Dynamic>
{
	public var section(get, never):Int;
	public var time(get, never):Float;
	public var name(get, never):String;

	inline function get_section():Int
		return this[0];

	inline function get_time():Float
		return this[1];

	inline function get_name():String
		return this[3];
}
