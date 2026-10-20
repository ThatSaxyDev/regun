"""Warm, short reload foley from recorded CC0 weapon mechanisms.
See art/source/audio/README.md. ffmpeg required; no API or Python dependencies.
"""
from pathlib import Path
import csv, math, struct, subprocess, wave
ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
# Source, trim, pitch ratio, tempo correction, output duration, low-pass, peak.
# Source pitch drops slightly; atempo keeps each action short without brightening it.
CUES = {
    'shotgun_shell': ('handgun_reload_zer0sol.wav', .55, .81, .82, 1.65, .20, 1800, .38),
    'shotgun_pump': ('shotgun_pump_springyspringo.wav', .025, .41, .86, 1.85, .26, 2400, .60),
    'carbine_0': ('rifle_reload_springyspringo.wav', .14, .49, .88, 1.75, .25, 2200, .46),
    'carbine_1': ('rifle_reload_springyspringo.wav', .97, 1.19, .88, 1.22, .23, 2200, .50),
    'carbine_2': ('rifle_reload_springyspringo.wav', 1.18, 1.51, .86, 1.70, .25, 2400, .56),
    'revolver_0': ('handgun_reload_zer0sol.wav', .08, .24, .85, 1.05, .20, 2300, .44),
    'revolver_1': ('handgun_reload_zer0sol.wav', .55, .81, .84, 1.55, .23, 2100, .46),
    'revolver_2': ('handgun_reload_zer0sol.wav', 1.02, 1.33, .86, 1.65, .25, 2400, .54),
    'arcCaster_0': ('rifle_reload_springyspringo.wav', .14, .49, .78, 1.80, .28, 1900, .44),
    'arcCaster_1': ('handgun_reload_zer0sol.wav', .55, .81, .78, 1.50, .25, 1700, .46),
    'arcCaster_2': ('shotgun_pump_springyspringo.wav', .025, .41, .78, 1.80, .30, 2100, .54),
}


def generate():
    rows = []
    for cue, (source, start, end, pitch, tempo, duration, cutoff, peak) in CUES.items():
        filters = (f'atrim=start={start}:end={end},asetpts=PTS-STARTPTS,'
                   f'asetrate={round(RATE*pitch)},aresample={RATE},atempo={tempo},'
                   f'highpass=f=85,lowpass=f={cutoff}:p=2,lowpass=f=3200:p=2,bass=g=3:f=220')
        data = subprocess.check_output(['ffmpeg', '-v', 'error', '-i',
            str(ROOT/'art/source/audio'/source), '-ac', '1', '-ar', str(RATE),
            '-af', filters, '-f', 's16le', '-'])
        a = [x/32768 for x in struct.unpack('<'+'h'*(len(data)//2), data)]
        count = round(RATE*duration)
        a = (a+[0.0]*count)[:count]
        # Gentle onset and release, DC correction and bounded peaks.
        mean = sum(a)/len(a)
        a = [(x-mean)*min(1, i/(RATE*.003), (count-1-i)/(RATE*.012))
             for i,x in enumerate(a)]
        gain = peak/max(max(map(abs, a)), .001)
        a = [x*gain for x in a]
        name = f'reload_{cue}.wav'
        with wave.open(str(ROOT/'assets/audio'/name), 'wb') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
            f.writeframes(struct.pack('<'+'h'*len(a), *[round(x*32767) for x in a]))
        rows.append([name, duration, round(max(map(abs,a)),4),
                     round(math.sqrt(sum(x*x for x in a)/len(a)),4), 'recorded_'+cue, 0])
    manifest = ROOT/'docs/art/WEAPON_AUDIO_MANIFEST.csv'
    old = list(csv.reader(manifest.open())) if manifest.exists() else [
        ['file','seconds','peak','rms','event','seed']]
    names = {row[0] for row in rows}
    with manifest.open('w', newline='') as f:
        writer = csv.writer(f, lineterminator='\n')
        writer.writerows([old[0]]+[row for row in old[1:] if row[0] not in names]+rows)
    print(f'Wrote {len(rows)} recorded reload cues: mono PCM16/{RATE} Hz.')

if __name__ == '__main__':
    generate()
