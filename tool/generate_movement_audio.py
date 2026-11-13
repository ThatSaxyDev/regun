"""Extract Regun movement and enemy cues from recorded Foley."""
import struct
import subprocess
import wave
from pathlib import Path

RATE = 44_100
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio"


def extract(name, surface, start, duration, cutoff, peak, *, attack=.006, release=.042):
    source = OUTPUT.parent.parent / "art/source/audio/movement" / f"{surface}.mp3"
    filters = (
        f"highpass=f=75,lowpass=f={cutoff},"
        "acompressor=threshold=0.045:ratio=2.8:attack=1:release=28,"
        f"afade=t=in:d={attack},afade=t=out:st={duration - release}:d={release}"
    )
    pcm = subprocess.check_output([
        "ffmpeg", "-v", "error", "-ss", str(start), "-i", str(source),
        "-t", str(duration), "-ac", "1", "-ar", str(RATE),
        "-af", filters, "-f", "s16le", "-",
    ])
    samples = [sample for sample, in struct.iter_unpack("<h", pcm)]
    scale = peak / max(map(abs, samples))
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(struct.pack(f"<{len(samples)}h", *(
            round(sample * scale) for sample in samples
        )))


for surface, starts, cutoff, peak in [
    ("stone", (.675, 1.792, 2.992), 2350, 13500),
    ("metal", (1.095, 2.173, 3.744), 3000, 12000),
    ("wet", (.513, 20.428, 33.641), 2900, 12500),
]:
    for index, start in enumerate(starts):
        extract(f"step_{surface}_{index}", surface, start, .205, cutoff, peak)

extract("dash_land", "stone", 1.792, .265, 1950, 15000)
# Use gravel after the heel strike and the middle of a continuous stone drag.
extract("enemy_scuttle", "gravel", 1.58, .24, 2200, 9500, attack=.025)
extract("enemy_skitter_warn", "claw", 1.91, .43, 2900, 14500, attack=.025)

# Machinery uses continuous recorded motion and a separate low steel contact.
extract("machine_press_charge", "press", 3.20, .70, 1600, 10500, attack=.12, release=.10)
extract("machine_press_hit", "press", 18.48, .42, 1200, 19500, attack=.014, release=.16)
extract("machine_sluice_charge", "sluice", 1.0, 1.6, 790, 9500, attack=.48, release=.12)
extract("machine_sluice_flow", "sluice", 3.0, 2.7, 3300, 17000, attack=.13, release=.57)
extract("machine_relay_charge", "relay", 6.25, 1.05, 1450, 11000, attack=.19, release=.09)
extract("machine_relay_pulse", "relay", 17.88, .39, 2800, 15200, attack=.025, release=.14)

# Expedition arrival: a low, continuous mechanical scrape with a planted clunk.
# Both layers are recorded metal-on-concrete from the press source.
def generate_arrival():
    source = OUTPUT.parent.parent / "art/source/audio/movement/press.mp3"
    filters = (
        "[0:a]atrim=start=3.20:duration=0.56,asetpts=PTS-STARTPTS,"
        "asetrate=35280,aresample=44100,highpass=f=78,lowpass=f=1300,"
        "afade=t=in:d=0.04,afade=t=out:st=0.45:d=0.25[drag];"
        "[0:a]atrim=start=18.48:duration=0.28,asetpts=PTS-STARTPTS,"
        "asetrate=37485,aresample=44100,highpass=f=90,lowpass=f=1600,"
        "afade=t=in:d=0.008,afade=t=out:st=0.18:d=0.14,adelay=345[clunk];"
        "[drag][clunk]amix=inputs=2:weights='0.85 1':normalize=0,"
        "acompressor=threshold=0.026:ratio=4:attack=0.5:release=40[out]"
    )
    pcm = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(source), "-ar", str(RATE),
        "-filter_complex", filters, "-map", "[out]", "-ac", "1", "-f", "s16le", "-",
    ])
    samples = [sample for sample, in struct.iter_unpack("<h", pcm)]
    scale = 18500 / max(map(abs, samples))
    with wave.open(str(OUTPUT / "enemy_arrival.wav"), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(struct.pack(f"<{len(samples)}h", *(
            round(sample * scale) for sample in samples
        )))


generate_arrival()
