#!/usr/bin/env python3
"""Render only recorded actual VGA pin bytes and bounded public VCD windows."""
import argparse,hashlib,json,re,struct,subprocess,sys,zlib
from pathlib import Path
from vcd_to_svg import parse_vcd,Signal,render_svg
def sha(b):return hashlib.sha256(b).hexdigest()
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
def group_bits(trace,base,width):
 if base in trace.signals:return dict(name=base,source_bits=[base],transformation='none')
 signals=[trace.signals[f'{base}[{i}]'] for i in range(width)]
 updates={}
 for i,signal in enumerate(signals):
  for tick,bits in trace.events[signal.code]:updates.setdefault(tick,{})[i]=bits
 values=['x']*width;events=[]
 for tick,changes in sorted(updates.items()):
  for i,bits in changes.items():values[i]=bits
  value=''.join(reversed(values))
  if not events or events[-1][1]!=value:events.append((tick,value))
 code='__public_vector__'+base;assert code not in trace.events
 trace.events[code]=events;trace.signals[base]=Signal(base,code,width,'display-group',f'[{width-1}:0]')
 return dict(name=base,source_bits=[s.name for s in reversed(signals)],transformation='MSB-to-LSB vector display assembled from recorded public scalar-bit values at each timestamp; original VCD unchanged')
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
 # Decode representative pixels back to RGB332 only for an independent artwork
 # signature check. The PNG above is built exclusively from actual RGB samples.
 atlas=bytearray();expected=bytearray()
 for row in range(60):
  for col in range(80):
   i=((row*8)*800+col*8)*4;red,green,blue=raw[i:i+3]
   assert red&1==red>>3 and green&1==green>>3 and blue in (0,5,10,15)
   atlas.append((red//2)*32+(green//2)*4+blue//5)
   p=224 if col<27 else (28 if col<54 else 3)
   if row in range(24,35):
    d=col==28 or (row in (24,34) and col in range(28,34)) or (col==34 and row in range(25,34))
    letter_i=col==40 or (row in (24,34) and col in range(38,43))
    letter_l=col==46 or (row==34 and col in range(46,53))
    if d or letter_i or letter_l:p=255
   expected.append(p)
 assert atlas==expected
 (a.output/'initial-framebuffer-from-pins.bin').write_bytes(atlas)
 save(a.output/'initial-artwork-signature.json',dict(label='Initial three-band RGB332 background and retained DIL signature',actual_source='actual-frame.rgb444',actual_source_sha256=sha(raw),actual_decoded_framebuffer_sha256=sha(atlas),expected_specification_framebuffer_sha256=sha(expected),framebuffer_dimensions=[80,60],method='One recorded actual active pixel at each 8 by 8 cell origin, inverse RGB332 mapping; expected bytes independently constructed from the documented initial artwork. PNG pixels are never supplied by the expected atlas.'))
 start=int(re.search(r'^# VGA_FRAME_CAPTURE_START time=(\d+) clock=\d+',log,re.M)[1]);end=int(re.search(r'^# VGA_FRAME_CAPTURE_PASS pixels=420000 time=(\d+)',log,re.M)[1]);assert end-start==(420000-1)*40000
 save(image.with_suffix('.json'),dict(label='simulation-reconstructed frame',source=str(f/'actual-frame.rgb444'),source_sha256=sha(raw),source_representation='four exact actual-pin bytes per raster sample: R4 G4 B4 {HS,VS,ACTIVE}',image_sha256=sha(png),image_dimensions=[640,480],raster_dimensions=[800,525],sample_phase='first rising input clock of each raster pixel (post-model divider=1), output captured +1 ns after edge',input_period_ns=10,sample_period_ns=40,start_tick_ps=start,end_tick_ps=end,conversion='each observed 4-bit channel multiplied by 17',active_samples=active,hsync_low_samples=hs,vsync_low_samples=vs,source_revision=result['source_revision'],renderer_sha256=sha(Path(__file__).read_bytes()),command=[sys.executable,*sys.argv]))
 waves=[];vcd=f/'pins.vcd';assert vcd.is_file() and vcd.stat().st_size
 trace=parse_vcd(vcd);grouping=[group_bits(trace,'vga_uvm_top.bus.'+name,width) for name,width in [('sram_addr',13),('sram_data_in',8),('red',4),('green',4),('blue',4)]]
 selected={'horizontal':['clk','hsync','active_video','red','green','blue'],
  'vertical_sync':['hsync','vsync','active_video','reset'],
  'frame_wrap':['clk','hsync','vsync','active_video','red','green','blue'],
  'current_pixel':['clk','sram_we','sram_addr','sram_data_in','active_video','red','green','blue'],
  'async_reset':['clk','reset','sram_we','sram_addr','sram_data_in','red','green','blue','active_video']}
 for name in ('horizontal','vertical_sync','frame_wrap','current_pixel','async_reset'):
  begin=int(re.search(r'^# VGA_WAVE_START name='+name+r' time=(\d+)',log,re.M)[1]);finish=int(re.search(r'^# VGA_WAVE_END name='+name+r' time=(\d+)',log,re.M)[1]);assert finish>begin
  figure=a.output/(name+'.svg')
  pins=[trace.signals['vga_uvm_top.bus.'+p] for p in selected[name]];source_hash=sha(vcd.read_bytes())
  figure.write_text(render_svg(trace,pins,begin,finish,'Measured VGA '+name,'simulator',source_hash,vcd.name),encoding='utf-8')
  meta=dict(origin='simulator',source_sha256=source_hash,source_filename=vcd.name,timescale=trace.timescale,start_tick=begin,end_tick=finish,source_final_tick=trace.last_tick,signals=[vars(s) for s in pins],public_bit_grouping=grouping,same_tick_collapses=trace.same_tick_collapses,functional_result='NOT_ASSESSED_BY_RENDERER',source_revision=result['source_revision'],command=[sys.executable,*sys.argv])
  save(figure.with_suffix('.json'),meta)
  waves.append(dict(name=name,test='functional',source_revision=result['source_revision'],capture=str(vcd),source_sha256=source_hash,start_tick=begin,end_tick=finish,figure=figure.name,command=[sys.executable,*sys.argv],renderer_sha256=sha(Path(__file__).read_bytes()),exit_code=0))
 save(a.output/'WAVEFORMS.json',waves)
 print(json.dumps(dict(status='PASS',frame_samples=420000,active_pixels=active,image_sha256=sha(png),waveforms=len(waves))))
if __name__=='__main__':main()
