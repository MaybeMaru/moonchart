package moonchart.formats.fnf;

import moonchart.backend.Resolver;
import moonchart.backend.Util;
import moonchart.formats.BasicFormat.BasicEvent;
import moonchart.formats.BasicFormat.BasicNoteType;
import moonchart.formats.fnf.legacy.*;

abstract FNFLegacyNoteType(Dynamic) from Int8 to Int8 from String to String from Dynamic to Dynamic {}
typedef FNFNoteTypeResolver = Resolver<FNFLegacyNoteType, BasicFNFNoteType>;

enum abstract BasicFNFNoteType(String) from String to String from BasicNoteType to BasicNoteType
{
	var CHEER;
	var ALT_ANIM;
	var NO_ANIM;
	var GF_SING;
	var CENSOR;
}

enum abstract BasicFNFNoteSkin(String) from String
{
	var DEFAULT_SKIN = "";
	var PIXEL_SKIN;
}

enum abstract BasicFNFCamFocus(Int8) from Int8 to Int8
{
	var BF = 0;
	var DAD = 1;
	var GF = 2;
}

/**
 * This class is NOT a Format, its made as a linker between other FNF formats
 * Since FNF formats have a lot of shared data but different ways to represent it
 */
class FNFGlobal
{
	/**
	 * Creates a ``FNFNoteTypeResolver`` instance for use with FNF Note types
	 * TODO: should prob make this a basic class with an FNF extension of it
	 */
	public static inline function createNoteTypeResolver():FNFNoteTypeResolver
	{
		return new Resolver(DEFAULT, DEFAULT);
	}

	/**
	 * This is the main place where you want to store ways to resolve FNF cam movement events.
	 * The resolve method should always return a ``BasicFNFCamFocus``.
	 */
	public static var camFocus(get, null):Map<String, BasicEvent->BasicFNFCamFocus>;

	static function get_camFocus()
	{
		if (camFocus != null)
			return camFocus;

		camFocus = [];
		camFocus.set(FNFLegacy.FNF_LEGACY_MUST_HIT_SECTION_EVENT, (e) -> e.data.mustHitSection ? BF : DAD);
		camFocus.set(FNFVSlice.VSLICE_FOCUS_EVENT, (e) -> Std.parseInt(Std.string(e.data.char)));
		camFocus.set(FNFCodename.CODENAME_CAM_MOVEMENT, (e) ->
		{
			return switch (e.data.array[0])
			{
				case 0: DAD;
				case 1: BF;
				default: GF;
			}
		});

		return camFocus;
	}

	public static inline function resolveCamFocus(event:BasicEvent):BasicFNFCamFocus
	{
		return camFocus.get(event.name)(event);
	}

	public static inline function isCamFocus(event:BasicEvent):Bool
	{
		return camFocus.exists(event.name);
	}

	public static inline function filterEvents(events:Array<BasicEvent>,)
	{
		return events.filter((e) -> return !isCamFocus(e));
	}
}
