# Moonchart

## What is Moonchart?
Moonchart is a Haxelib backend tool designed to manage the chart file formats of various rhythm games at the same time.<br>
It can be used to load, parse and convert between multiple formats efficiently.

## How to use Moonchart
Here's an example in pseudo haxe code of how to convert 2 basic formats between eachother, it works about the same between all formats.
Some may need a metadata file (like the FNF (V-Slice) Format) to work.

```haxe
import moonchart.formats.fnf.legacy.FNFLegacy;
import moonchart.formats.fnf.FNFVSlice;

// Load an FNF (Legacy) chart and set the difficulty level to "hard"
var funkinLegacy = new FNFLegacy().fromFile("path/to/chart.json", null, "hard");

// Convert the FNF (Legacy) chart format to the FNF (V-Slice) format
var funkinVSlice = new FNFVSlice().fromFormat(funkinLegacy);

// Access the converted FNF (V-Slice) format data using the following variables
var vSliceData = funkinVSlice.data; // Contains the chart data
var vSliceMeta = funkinVSlice.meta; // Contains the metadata

// To save the chart in its original file format, use the stringify method to generate the file strings
var vsliceChart = funkinVSlice.stringify();
var chart:String = vsliceChart.data; // String containing the FNF (V-Slice) chart data
var meta:String = vsliceChart.meta;  // String containing the FNF (V-Slice) metadata
```

## Available formats
| Format               | File Extension       |
|----------------------|----------------------|
| [FNF (Legacy)](https://github.com/FunkinCrew/Funkin/tree/v0.2.7.1)            | json |
| [FNF (Psych Engine)](https://github.com/ShadowMario/FNF-PsychEngine)          | json |
| [FNF (FPS +)](https://github.com/ThatRozebudDude/FPS-Plus-Public)             | json |
| [FNF (Kade Engine)](https://github.com/Kade-github/Kade-Engine)               | json |
| [FNF (Maru)](https://github.com/MaybeMaru/Maru-Funkin)                        | json |
| [FNF (Codename)](https://github.com/FNF-CNE-Devs/CodenameEngine)              | json |
| [FNF (Imaginative)](https://github.com/Funkin-Imaginative/imaginative.engine) | json |
| [FNF (Ludum Dare)](https://github.com/FunkinCrew/Funkin/tree/1.0.0)           | json / png |
| [FNF (V-Slice)](https://github.com/FunkinCrew/Funkin)                         | json |
| [Guitar Hero](https://clonehero.net/)                                         | chart |
| [Osu! Mania](https://osu.ppy.sh/)                                             | osu |
| [Quaver](https://quavergame.com/)                                             | qua |
| [StepMania](https://www.stepmania.com/)                                       | sm |
| [StepManiaShark](https://www.stepmania.com/)                                  | ssc |

## Encountered a problem?
If you discover a bug or run into any other issue while using the library, please don't hesitate to open a [GitHub issue](https://github.com/MaybeMaru/moonchart/issues).<br>
You can also reach out to me directly via Discord at ``maybemaru``.