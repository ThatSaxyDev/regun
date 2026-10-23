"""Normalize all four creator-selected clips in full; no trimming/speed changes."""
from pathlib import Path
import subprocess,json,hashlib,math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'public/weapon-recordings';OUT.mkdir(exist_ok=True)
SOURCES=[('arc','09-41-35'),('rail','09-42-16'),('frost','09-43-32'),('rivet','09-44-13')]
manifest=[]
for key,stamp in SOURCES:
 source=Path('/Users/kiishidavid/Downloads')/f'ScreenRecording_10-23-2026 {stamp}_1.mov'
 info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(source)]))
 duration=float(info['format']['duration']);target=OUT/f'{key}.mp4'
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-map','0:v:0','-map','0:a:0?','-vf','scale=1920:-2,fps=60','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(target)],check=True)
 manifest.append({'key':key,'source':str(source),'source_duration':duration,'frames':math.ceil(duration*60),'file':f'weapon-recordings/{key}.mp4','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'edit':'Full original clip; no trim, speed change or loop. Orientation normalized; 60fps H264.'})
 print(key,duration,flush=True)
(ROOT/'src/weapon-recordings.ts').write_text('export const recordings = '+json.dumps(manifest,indent=2)+' as const;\n')
