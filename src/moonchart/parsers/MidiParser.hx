package moonchart.parsers;

import haxe.io.Bytes;
import haxe.io.BytesInput;

typedef MidiFormat =
{
	header:String,
	headerLength:Int,
	format:Int,
	division:Int,
	tracks:Array<MidiTrack>
}

typedef MidiTrack = Array<MidiEvent>;

/**
 * Mostly a copy of https://gitlab.com/haxe-grig/grig.midi/
 * All credits to the original authors
 */
class MidiParser extends BasicParser<MidiFormat>
{
	var tracks:Array<MidiTrack> = [];
	var input:BytesInput;

	// TODO:
	override function encode(data:MidiFormat):Bytes
	{
		return null;
	}

	public function parseBytes(bytes:Bytes):MidiFormat
	{
		tracks.resize(0);

		input = new BytesInput(bytes);
		input.bigEndian = true;

		var header:String = input.readString(4);
		if (header != "MThd")
			throw 'Invalid midi header ($header)';

		var headerLength = input.readInt32();
		if (headerLength != 6)
			throw 'Invalid midi header length ($headerLength)';

		var format = input.readUInt16();
		var tracksLength:Int = input.readUInt16();
		var division = input.readUInt16();

		for (i in 0...tracksLength)
		{
			var track:MidiTrack = new MidiTrack();
			parseTrack(track);
			tracks.push(track);
		}

		return {
			header: header,
			headerLength: headerLength,
			format: format,
			division: division,
			tracks: tracks
		}
	}

	function parseTrack(track:MidiTrack)
	{
		var header:String = input.readString(4);
		if (header != "MTrk")
			throw 'Invalid midi track header ($header)';

		var size:Int = input.readInt32();
		var absoluteTime:Int = 0;
		var lastFlag:Int = 0;

		while (size > 0)
		{
			var variableBytes = readVariableBytes(input);
			size -= variableBytes.length;

			var delta:Int = variableBytes.value;
			absoluteTime += delta;

			var flag = input.readByte();
			size--;

			switch (flag)
			{
				case 0xFF:
					var type = input.readByte();
					var metaLength = readVariableBytes(input);
					size = size - 1 - metaLength.length - metaLength.value;
					track.push(MidiEventType.getEvent(type, absoluteTime, metaLength.value, input));
				case 0xF0:
					var messageBytes = [flag];
					while (true)
					{
						var byte = input.readByte();
						messageBytes.push(byte);
						size--;
						if (byte == 0xF7)
						{
							break;
						}
					}
					track.push(MESSAGE(messageBytes, absoluteTime));
				default:
					var messageType = MidiMessageType.ofByte(flag);
					var messageBytes:Array<Int> = [];
					var runningStatus = false;
					if (messageType == UNKNOWN)
					{
						messageBytes[0] = lastFlag;
						messageType = MidiMessageType.ofByte(lastFlag);
						runningStatus = true;
					}
					else
					{
						messageBytes[0] = flag;
						lastFlag = flag;
					}

					var messageSize = MidiMessageType.sizeForMessageType(messageType);
					if (runningStatus)
						messageSize--;

					for (i in 1...messageSize)
					{
						messageBytes[i] = input.readByte();
						size--;
					}

					track.push(MESSAGE(messageBytes, absoluteTime));
			}
		}
	}

	static function readVariableBytes(input:BytesInput)
	{
		var length:Int = 0;
		var value:Int = input.readByte();
		length++;

		if (value & 0x80 != 0)
		{
			value = value & 0x7F;
			while (true)
			{
				var newByte = input.readByte();
				length++;
				value = (value << 7) + (newByte & 0x7F);
				if (newByte & 0x80 == 0)
				{
					break;
				}
			}
		}

		return {value: value, length: length};
	}
}

enum MidiEvent
{
	TEMPO_CHANGE(tempo:Int, tick:Int);
	TIME_SIGNATURE(num:Int, den:Int, clock:Int, tick:Int);
	MESSAGE(byteArray:Array<Int>, tick:Int);
	END_TRACK(tick:Int);
	TEXT(text:String, tick:Int, type:Int);
	TRACK_NAME(name:String, tick:Int);
}

enum abstract MidiEventType(Int) from Int to Int
{
	var SEQUENCE_EVENT = 0x00;
	var CHANNEL_PREFIX_EVENT = 0x20;
	var PORT_PREFIX_EVENT = 0x21;
	var END_TRACK_EVENT = 0x2F;
	var TEMPO_CHANGE_EVENT = 0x51;
	var OFFSET_EVENT = 0x54;
	var TIME_SIGNATURE_EVENT = 0x58;
	var KEY_SIGNATURE_EVENT = 0x59;
	var SEQUENCER_SPECIFIC_EVENT = 0x7F;

	public static function getEvent(type:MidiEventType, absoluteTime:Int, metaLength:Int, input:BytesInput):MidiEvent
	{
		return switch (type)
		{
			case 0x01: TEXT(input.readString(metaLength), absoluteTime, type); // General text
			case 0x03: TRACK_NAME(input.readString(metaLength), absoluteTime); // Track name (song title)
			// case SEQUENCE_EVENT: null;
			// case CHANNEL_PREFIX_EVENT: null;
			// case PORT_PREFIX_EVENT: null;
			case END_TRACK_EVENT: END_TRACK(absoluteTime);
			case TEMPO_CHANGE_EVENT: TEMPO_CHANGE(Std.int(input.readUInt24() / 6000), absoluteTime);
			// case OFFSET_EVENT: null;
			case TIME_SIGNATURE_EVENT: TIME_SIGNATURE(input.readByte(), input.readByte(), input.readByte(), input.readByte());
			// case KEY_SIGNATURE_EVENT: null;
			// case SEQUENCER_SPECIFIC_EVENT: null;
			default:
				throw 'Invalid midi event type ($type)';
		}
	}
}

enum abstract MidiMessageType(Int) from Int to Int
{
	var NOTE_OFF = 0x80;
	var NOTE_ON = 0x90;
	var POLY_PRESSURE = 0xA0;
	var CONTROL_CHANGE = 0xB0;
	var PROGRAM_CHANGE = 0xC0;
	var PRESSURE = 0xD0;
	var PITCH = 0xE0;
	var SYS_EX = 0xF0;
	var TIME_CODE = 0xF1;
	var SONG_POSITION = 0xF2;
	var SONG_SELECT = 0xF3;
	var TUNE_REQUEST = 0xF6;
	var TIME_CLOCK = 0xF8;
	var START = 0xFA;
	var CONTINUE = 0xFB;
	var STOP = 0xFC;
	var KEEP_ALIVE = 0xFE;
	var RESET = 0xFF;
	var UNKNOWN = 0;

	public static function ofByte(byte:Int):MidiMessageType
	{
		return switch (byte >> 0x04)
		{
			case 0x8: NOTE_OFF;
			case 0x9: NOTE_ON;
			case 0xA: POLY_PRESSURE;
			case 0xB: CONTROL_CHANGE;
			case 0xC: PROGRAM_CHANGE;
			case 0xD: PRESSURE;
			case 0xE: PITCH;
			case 0xF: {
					switch (byte & 0xF)
					{
						case 0x0: SYS_EX;
						case 0x1: TIME_CODE;
						case 0x2: SONG_POSITION;
						case 0x3: SONG_SELECT;
						case 0x6: TUNE_REQUEST;
						case 0x8: TIME_CLOCK;
						case 0xA: START;
						case 0xB: CONTINUE;
						case 0xC: STOP;
						case 0xE: KEEP_ALIVE;
						case 0xF: RESET;
						default: UNKNOWN;
					}
				}
			default: UNKNOWN;
		}
	}

	public static function sizeForMessageType(type:MidiMessageType):Int
	{
		return switch (type)
		{
			case NOTE_ON: 3;
			case NOTE_OFF: 3;
			case POLY_PRESSURE: 3;
			case CONTROL_CHANGE: 3;
			case PROGRAM_CHANGE: 2;
			case PRESSURE: 2;
			case PITCH: 3;
			case TIME_CODE: 2;
			case SONG_POSITION: 3;
			case SONG_SELECT: 2;
			case TUNE_REQUEST: 1;
			case TIME_CLOCK: 1;
			case START: 1;
			case CONTINUE: 1;
			case STOP: 1;
			case KEEP_ALIVE: 1;
			case RESET: 1;
			case SYS_EX: throw "Cannot determine length of sysex messages ahead of time";
			case UNKNOWN: throw 'Unknown midi message type: $type';
		}
	}
}
