// Source sketch for the replacement BGM.
// Intended mood: 1980s/1990s township game loop, pentatonic, modest chiptune.
// Runtime uses the rendered WAV at res://assets/audio/bgm/shuangqiao_town_loop.wav.

const lead = note("<g4 a4 c5 d5 c5 a4 g4 e4>")
  .slow(2)
  .sound("square")
  .gain(0.45)
  .room(0.15);

const answer = note("<e4 g4 a4 c5 a4 g4 e4 d4>")
  .slow(2)
  .sound("triangle")
  .gain(0.28);

const bass = note("<c2 c2 g1 g1 a1 a1 f1 g1>")
  .sound("sawtooth")
  .gain(0.32);

const pulse = s("bd ~ sd ~ bd bd sd ~").gain(0.22);

stack(lead, answer, bass, pulse).cpm(72 / 4);
