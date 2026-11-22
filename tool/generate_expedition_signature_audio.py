"""Generate grounded Expedition signature cues from attributed Regun Foley."""
import math
import struct
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/audio"
RATE = 44_100

# source, source start, source duration, playback pitch, low-pass ceiling,
# placement in the cue, weight
STONE = ("movement/stone.mp3", 1.792)
GRIT = ("movement/gravel.mp3", 1.58)
STEEL = ("movement/press.mp3", 18.48)
DRAG = ("movement/press.mp3", 3.20)
SNAP = ("shotgun_pump_springyspringo.wav", 0)
CANNON = ("cannon_01.ogg", 0)
SHOT = ("shot_01.ogg", 0)

CUES = {
    "fracture": (.46, .72, [
        (*STONE, .20, .88, 3800, 0, .90),
        (*SHOT, .13, .78, 1150, .013, .28),
        (*GRIT, .23, .86, 2800, .073, .75),
    ]),
    "fuse": (.49, .74, [
        (*CANNON, .27, .86, 3300, 0, .82),
        (*STEEL, .22, 1.12, 4100, .018, .62),
        (*GRIT, .22, 1.03, 4150, .095, .44),
    ]),
    "fusePrimer": (.23, .45, [
        (*DRAG, .18, 1.17, 4900, 0, .85),
        (*SNAP, .075, 1.36, 4600, .092, .35),
    ]),
    "breach": (.31, .64, [
        (*SHOT, .16, .76, 1940, 0, .64),
        (*STEEL, .17, .84, 2200, .035, .64),
    ]),
    "thunder": (.34, .66, [
        (*SHOT, .096, 1.20, 5800, 0, .58),
        (*DRAG, .19, 1.55, 3900, .026, .82),
        (*STEEL, .08, 1.19, 4800, .112, .37),
    ]),
    "flash": (.29, .63, [
        (*SHOT, .11, .94, 4700, 0, .82),
        (*GRIT, .15, 1.27, 4800, .052, .53),
    ]),
    "frost": (.34, .61, [
        (*SNAP, .10, 1.48, 6200, 0, .70),
        (*GRIT, .22, 1.35, 6200, .033, .64),
    ]),
    "shatter": (.25, .65, [
        (*STEEL, .075, 1.51, 7100, 0, .67),
        (*GRIT, .13, 1.76, 7200, .026, .58),
    ]),
    "deadeye": (.24, .63, [
        (*SNAP, .081, 1.25, 5800, 0, .70),
        (*SHOT, .11, 1.32, 3200, .045, .43),
    ]),
    "curtain": (.34, .62, [
        (*DRAG, .21, 1.19, 4200, 0, .76),
        (*STEEL, .11, 1.35, 5500, .051, .54),
    ]),
    "slag": (.43, .60, [
        (*DRAG, .33, .99, 3500, 0, .76),
        (*GRIT, .21, 1.41, 5000, .041, .66),
    ]),
    "backlash": (.32, .66, [
        (*STEEL, .20, .72, 2600, 0, .85),
        (*STONE, .19, .79, 1500, .028, .53),
    ]),
    "quickdraw": (.24, .60, [
        (*STEEL, .14, 1.31, 4250, 0, .74),
        (*SNAP, .089, 1.42, 5650, .059, .46),
    ]),
    "quickdrawChamber": (.14, .46, [
        (*SNAP, .11, 1.12, 4200, 0, 1),
    ]),
    "blood": (.31, .49, [
        (*DRAG, .22, 1.29, 1550, 0, .74),
        (*SNAP, .105, .91, 2300, .083, .54),
    ]),
}


def generate(name, duration, peak, layers):
    samples = [0.0] * round(duration * RATE)
    for path, start, length, pitch, cutoff, offset, weight in layers:
        raw = subprocess.check_output([
            "ffmpeg", "-v", "error", "-ss", str(start), "-i", str(SOURCE / path),
            "-t", str(length), "-ac", "1", "-ar", str(RATE), "-af",
            f"asetrate={round(RATE * pitch)},aresample={RATE},"
            f"highpass=f=90,lowpass=f={cutoff}", "-f", "s16le", "-",
        ])
        layer = [value for value, in struct.iter_unpack("<h", raw)]
        level = max(1, max(map(abs, layer), default=0))
        begin = round(offset * RATE)
        for index, value in enumerate(layer[:len(samples) - begin]):
            t = index / RATE
            window = max(0, min(1, t / .004, (length - t) / .023))
            samples[begin + index] += weight * value * window / level
    source_peak = max(map(abs, samples))
    normalized = [
        math.tanh(value / source_peak * 1.3) / math.tanh(1.3) * peak
        for value in samples
    ]
    rms = math.sqrt(sum(value * value for value in normalized) / len(normalized))
    assert .018 < rms < .26 and normalized[0] == normalized[-1] == 0, (name, rms)
    asset = ROOT / "assets/audio" / f"signature_{name}.wav"
    with wave.open(str(asset), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(struct.pack(
            f"<{len(normalized)}h", *(round(value * 32767) for value in normalized)
        ))
    print(f"{asset.name} {duration:.2f}s peak={peak:.2f} rms={rms:.3f}")


if __name__ == "__main__":
    for cue, settings in CUES.items():
        generate(cue, *settings)
