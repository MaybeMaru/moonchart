package moonchart;

import moonchart.formats.StepMania;

class Main {
  static function main()@:privateAccess {
    /*var sm = new StepMania({
      TITLE: "",
      OFFSET: 0,
      NOTES: ["fucky" => {
        dance: SINGLE,
        diff: "hard",
        notes: []
      }],
      BPMS: [{
        bpm: 100,
        beat: 0
      }]
    });*/
    var data = moonchart.backend.FormatDetector.getFormatData(STEPMANIA);
    trace(data);
  }
}