"""Create static scene images and synthesize original looping audio.
Requires ffmpeg and numpy. No downloaded music or stock media is used.
"""
from pathlib import Path
import subprocess, concurrent.futures, wave, numpy as np
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parent.parent/'assets/ambience'
OUT.mkdir(exist_ok=True, parents=True)
D=24; FPS=20; SR=32000
scenes=['forest','emerald','ruby','ocean','amethyst','amber','mono']

def audio(name,index):
 rng=np.random.default_rng(8221+index)
 n=D*SR;t=np.arange(n)/SR
 # Periodic low-pass colored noise: gentle rustle/water, no sharp high frequencies.
 freq=np.fft.rfftfreq(n,1/SR)
 coeff=(rng.normal(size=len(freq))+1j*rng.normal(size=len(freq)))
 coeff*= (np.maximum(freq,90)/90)**(-.9)*np.exp(-(freq/1700)**4)
 coeff[freq<70]=0
 noise=np.fft.irfft(coeff,n=n); noise/=max(abs(noise))
 wave_rate=3 if name=='ocean' else 2
 swell=.55+.45*np.sin(2*np.pi*wave_rate*t/D)**2
 sound=noise*swell*(.075 if name in ['ocean','emerald','mono'] else .035)
 # Slow pentatonic pad, integer frequency bins produce a clean 24-second loop.
 roots=[130.81,146.83,164.81,110,138.59,123.47,98]
 root=roots[index]
 for j,ratio in enumerate([1,1.5,2,2.5]):
  f=round(root*ratio*D)/D
  env=.45+.25*np.cos(2*np.pi*(j+1)*t/D+j)
  sound+=.027/(1+j*.4)*env*np.sin(2*np.pi*f*t+j*.3)
 # Sparse soft bell motifs in forest/ruby/amber, with a smooth wrap-around tail.
 if name in ['forest','ruby','amber']:
  for j,offset in enumerate([3,11,19]):
   f=round(root*[4,3,4.5][j]*D)/D
   age=(t-offset)%D
   env=(1-np.exp(-age*9))*np.exp(-age/2.4)
   sound+=.025*env*np.sin(2*np.pi*f*t)
 # Retain headroom, no hard limiting or clipping. Smooth stereo differences.
 right=.96*sound+.004*np.roll(noise,500)
 data=np.column_stack([sound,right])*4;data=np.clip(data,-.9,.9)
 path=ROOT/(name+'.wav')
 with wave.open(str(path),'wb') as w:
  w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes((data*32767).astype('<i2').tobytes())
 return path

def render(pair):
 index,name=pair; wav=audio(name,index); src=ROOT/'originals'/f'{name}.png'
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),
                 '-c:a','aac','-b:a','96k','-movflags','+faststart',
                 str(OUT/f'{name}.m4a')],check=True)
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(src),
                 '-vf','scale=720:480:force_original_aspect_ratio=increase,crop=720:480',
                 '-frames:v','1','-q:v','2',str(OUT/f'{name}.jpg')],check=True)
 print(name,round((OUT/f'{name}.m4a').stat().st_size/1024/1024,2),'MB',flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 list(pool.map(render,enumerate(scenes)))
