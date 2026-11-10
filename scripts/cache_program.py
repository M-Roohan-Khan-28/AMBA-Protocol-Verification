"""Deterministic public-pin schedule and independent accounting, no DUT inputs."""
FIELDS=('observations','clocks','writes','blocked_writes','resets','lookups','hits','misses','comparisons')
def pack(c=0,r=0,w=0,way=0,s=0,t=0,d=0):return (c<<16)|(r<<15)|(w<<14)|(way<<13)|(s<<11)|(t<<8)|d

class Plan:
 def __init__(self,name):self.name=name;self.rows=[];self.pins=0
 def pin(self,**kw):
  p=pack(**kw);self.rows.append(p);self.pins=p
 def reset(self):self.pin();self.pin(r=1);self.pin()
 def put(self,way,s,t,d):
  self.pin(w=1,way=way,s=s,t=t,d=d);self.pin(c=1,w=1,way=way,s=s,t=t,d=d);self.pin(s=s,t=t)
 def query(self,s,t,way=0,d=0):self.pin(s=s,t=t,way=way,d=d)
 def scan(self):
  for s in range(4):
   for t in range(8):self.query(s,t)

def build(name):
 p=Plan(name);p.reset()
 if name.startswith('tuple_'):
  _,w,s,t=name.split('_');w,s,t=map(int,(w,s,t));p.put(w,s,t,((w*131+s*37+t*19)^0xA7)&255);p.scan()
 elif name=='smoke':p.put(0,1,2,0xA5);p.put(1,1,3,0x3C);p.scan()
 elif name=='data_256':
  for d in range(256):p.put(1,2,6,d);p.query(2,5);p.query(2,6)
 elif name=='overwrite':
  for w in range(2):
   p.put(w,w,1,0x12);p.put(w,w,2,0x83);p.query(w,1);p.query(w,2);p.put(w,w,2,0xF6);p.scan()
 elif name.startswith('duplicate_'):
  s=int(name[-1]);p.put(0,s,5,0xA5);p.put(1,s,5,0x3C);p.query(s,5,way=1,d=0x71);p.put(0,s,4,0x72);p.query(s,5);p.query(s,4)
 elif name in ('entry_isolation','async_lookup','no_write','repeated_reset','post_reset_refill'):
  for w in range(2):
   for s in range(4):p.put(w,s,w+2,0x10+w*64+s*11)
  p.scan()
  if name=='entry_isolation':
   for w in range(2):
    for s in range(4):p.put(w,s,w+5,0x81+w*32+s);p.scan()
  elif name=='async_lookup':
   for s in (3,0,2,1,3,1,0):
    for t in (2,7,3,1):p.query(s,t)
  elif name=='no_write':
   for v in range(16):
    p.pin(way=v%2,s=v%4,t=2+v%2,d=(v*23)&255);p.pin(c=1,way=(v+1)%2,s=v%4,t=2+v%2,d=(v*37)&255)
   p.scan()
  else:
   for i in range(3):p.reset();p.scan();p.put(i%2,i%4,i,0x41+i);p.scan()
 elif name=='reset_pending':
  p.put(0,0,1,0xAA);p.pin(w=1,way=1,s=2,t=6,d=0x73)
  p.pin(r=1,w=1,way=1,s=2,t=6,d=0x73) # asynchronous before a write clock
  p.pin(c=1,r=1,w=1,way=1,s=2,t=6,d=0x73);p.pin(r=1);p.pin();p.scan()
 elif name=='reset_coincident':
  p.put(1,3,7,0xF1);p.pin(w=1,way=0,s=1,t=4,d=0x8B);p.pin(c=1,r=1,w=1,way=0,s=1,t=4,d=0x8B);p.pin();p.scan()
 elif name=='held_writes':
  for i in range(6):p.pin(w=1,way=i%2,s=i%4,t=i%8,d=0x40+i);p.pin(c=1,w=1,way=i%2,s=i%4,t=i%8,d=0x40+i)
  p.pin();p.scan()
 else:raise ValueError(name)
 p.pin() # every case ends at identical public idle pins
 return p

def serialize(plans):
 return ''.join(f'{p.name} 1 0\n'+''.join(f'{p.name} 0 {v:05x}\n' for v in p.rows)+f'{p.name} 2 0\n' for p in plans)

def counts(plans):
 # Independent Python ledger from the scheduled public pins. It is not used by
 # the HDL scoreboard to calculate expected lookup values.
 mem={};previous=0;out={}
 for p in plans:
  c=dict.fromkeys(FIELDS,0)
  for v in p.rows:
   if v==previous:continue
   clk,reset,wr,way=(v>>16)&1,(v>>15)&1,(v>>14)&1,(v>>13)&1
   s,t,d=(v>>11)&3,(v>>8)&7,v&255
   rise=clk and not(previous>>16&1);re=reset and not(previous>>15&1)
   c['observations']+=1;c['clocks']+=int(rise);c['resets']+=int(re)
   if re or(rise and reset):mem.clear()
   if rise and wr:
    if reset:c['blocked_writes']+=1
    else:mem[way,s]=(t,d);c['writes']+=1
   hit=any(mem.get((w,s),(None,None))[0]==t for w in (0,1))
   c['hits' if hit else 'misses']+=1;c['lookups']+=1;c['comparisons']+=2;previous=v
  out[p.name]=c
 return out
