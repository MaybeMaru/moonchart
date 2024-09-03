# Moonchart

## What is Moonchart?
Tired of having to deal with different chart formats and old converters?<br>
Moonchart is a Haxelib backend tool designed to manage the chart file formats of various rhythm games at the same time.<br>
It can be used to detect, load, and convert between multiple formats efficiently.

## How to use Moonchart
Here's an example of how to convert 2 basic formats between eachother, it works about the same between all formats.
Some may need a metadata file (like the FNF (V-Slice) Format) to work.
```haxe
// Loading up a FNF (Legacy) chart anf setting the internal difficulty to "hard"
var funkinLegacy = new FNFLegacy().fromFile("path/to/chart.json", null, "hard");

// Converting the  FNF (Legacy) chart format to the FNF (V-Slice) format
var funkinVSlice = new FNFVSlice().fromFormat(funkinLegacy);

// You can access the converted FNF (V-Slice) format data using the following variables
var vSliceData = funkinVSlice.data; // Contains the chart data
var vSliceMeta = funkinVSlice.meta; // Contains the metadata

// If you want to save the chart in its original file format, use the stringify method to generate the file strings
var vsliceChart = funkinVSlice.stringify();
var chart:String = vsliceChart.data; // String containing the FNF (V-Slice) chart data
var meta:String = vsliceChart.meta;  // String containing the FNF (V-Slice) metadata
```

## Available formats
| Format               |
|----------------------|
| [FNF (Legacy)](https://github.com/FunkinCrew/Funkin/tree/v0.2.7.1)         |
| [FNF (Psych Engine)](https://github.com/ShadowMario/FNF-PsychEngine)   |
| [FNF (FPS +)](https://github.com/ThatRozebudDude/FPS-Plus-Public)          |
| [FNF (Kade Engine)](https://github.com/Kade-github/Kade-Engine)          |
| [FNF (Maru)](https://github.com/MaybeMaru/Maru-Funkin)          |
| [FNF (Ludum Dare)](https://github.com/FunkinCrew/Funkin/tree/1.0.0)     |
| [FNF (V-Slice)](https://github.com/FunkinCrew/Funkin)        |
| [Guitar Hero](https://clonehero.net/)          |
| [Osu! Mania](https://osu.ppy.sh/)           |
| [Quaver](https://quavergame.com/)               |
| [StepMania](https://www.stepmania.com/)            |
| [StepManiaShark](https://www.stepmania.com/)            |
