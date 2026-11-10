#!/usr/bin/env python3
"""Render only recorded actual VGA pin bytes and bounded public VCD windows."""
import argparse,hashlib,json,re,struct,subprocess,sys,zlib
from pathlib import Path
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--run',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 assert not a.output.exists();a.output.mkdir(parents=True)
 result=json.loads((a.run/'results.json').read_bytes());f=a.run/'functional';log=(f/'2.log').read_text(encoding='utf-8')
 assert next(s for s in result['suites'] if s['name']=='functional')['status']=='PASS'
 raw=(f/'actual-frame.rgb444').read_bytes();assert len(raw)==800*525*4
 rgb=bytearray();active=hs=vs=0
 for i in range(800*525):
  r,g,b,pins=raw[4*i:4*i+4];y,x=divmod(i,800)
  assert r<=15 and g<=15 and b<=15 and pins<=7
  av=pins&1;h=(pins>>2)&1;v=(pins>>1)&1
  assert av==int(x<640 and y<480) and h==int(not 656<=x<752) and v==int(not 490<=y<492)
  if not h:hs+=1
  if not v:vs+=1
  if av:rgb.extend((r*17,g*17,b*17));active+=1
  else:assert (r,g,b)==(0,0,0)
 assert active==640*480 and hs==96*525 and vs==2*800 and len(rgb)==640*480*3
 scans=b''.join(b'\x00'+rgb[y*640*3:(y+1)*640*3] for y in range(480))
 png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',640,480,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scans,9))+chunk(b'IEND',b'')
 image=a.output/'simulation-reconstructed-frame.png';image.write_bytes(png)
 start=int(re.search(r'^# VGA_FRAME_CAPTURE_START time=(\d+) clock=\d+',log,re.M)[1]);end=int(re.search(r'^# VGA_FRAME_CAPTURE_PASS pixels=420000 time=(\d+)',log,re.M)[1]);assert end-start==(420000-1)*40000
 save(image.with_suffix('.json'),dict(label='simulation-reconstructed frame',source=str(f/'actual-frame.rgb444'),source_sha256=sha(raw),source_representation='four exact actual-pin bytes per raster sample: R4 G4 B4 {HS,VS,ACTIVE}',image_sha256=sha(png),image_dimensions=[640,480],raster_dimensions=[800,525],sample_phase='first rising input clock of each raster pixel (post-model divider=1), output captured +1 ns after edge',input_period_ns=10,sample_period_ns=40,start_tick_ps=start,end_tick_ps=end,conversion='each observed 4-bit channel multiplied by 17',active_samples=active,hsync_low_samples=hs,vsync_low_samples=vs,source_revision=result['source_revision'],renderer_sha256=sha(Path(__file__).read_bytes()),command=[sys.executable,*sys.argv]))
 waves=[];vcd=f/'pins.vcd';assert vcd.is_file() and vcd.stat().st_size
 for name in ('horizontal','vertical_sync','frame_wrap','current_pixel','async_reset'):
  begin=int(re.search(r'^# VGA_WAVE_START name='+name+r' time=(\d+)',log,re.M)[1]);finish=int(re.search(r'^# VGA_WAVE_END name='+name+r' time=(\d+)',log,re.M)[1]);assert finish>begin
  figure=a.output/(name+'.svg')
  command=[sys.executable,str(Path(__file__).with_name('vcd_to_svg.py')),'--vcd',str(vcd),'--signals',*[f'vga_uvm_top.bus.{p}' for p in ('clk','reset','sram_we','sram_addr*','sram_data_in*','hsync','vsync','active_video','red*','green*','blue*')],'--start',str(begin),'--end',str(finish),'--output',str(figure),'--origin','simulator','--title','Measured VGA '+name]
  run=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90);figure.with_suffix('.log').write_bytes(run.stdout);assert run.returncode==0,run.stdout
  meta=json.loads(figure.with_suffix('.json').read_bytes());assert meta['source_sha256']==sha(vcd.read_bytes())
  waves.append(dict(name=name,test='functional',source_revision=result['source_revision'],capture=str(vcd),source_sha256=sha(vcd.read_bytes()),start_tick=begin,end_tick=finish,figure=figure.name,command=command,exit_code=run.returncode))
 save(a.output/'WAVEFORMS.json',waves)
 print(json.dumps(dict(status='PASS',frame_samples=420000,active_pixels=active,image_sha256=sha(png),waveforms=len(waves))))
if __name__=='__main__':main()
