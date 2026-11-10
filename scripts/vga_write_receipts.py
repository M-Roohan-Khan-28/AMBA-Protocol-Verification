"""Independent reconciliation of intended drive windows and observed write edges."""
import csv,hashlib
from pathlib import Path
def reconcile(intents,accepted,end_tick):
 assert intents and intents[0]==(0,1,0,0,0) and end_tick>0
 assert all(len(row)==5 for row in [*intents,*accepted])
 assert all(a[0]<=b[0] for a,b in zip(intents,intents[1:]))
 assert all(0<=t<=end_tick and reset in (0,1) and we in (0,1) and 0<=addr<=8191 and 0<=data<=255 for t,reset,we,addr,data in intents)
 expected=[]
 for i,(start,reset,we,addr,data) in enumerate(intents):
  stop=intents[i+1][0] if i+1<len(intents) else end_tick
  # The only deliberately coincident change is reset; write data/enable/address
  # were established before the clock. Reject ambiguous clock-edge stimulus.
  if i and start>=5000 and (start-5000)%10000==0:assert intents[i][2:]==intents[i-1][2:]
  if not we:continue
  edge=5000+max(0,(start-5000+9999)//10000)*10000
  while edge<stop:
   expected.append((edge,reset,addr,data,int(addr<4800)));edge+=10000
 assert accepted==expected,('WRITE_WINDOW_ACCOUNTING',len(expected),len(accepted),next(((i,a,b) for i,(a,b) in enumerate(zip(expected,accepted)) if a!=b),None))
 return dict(intended_records=len(intents),accepted_clock_records=len(accepted),valid=sum(x[4] for x in accepted),ignored=sum(not x[4] for x in accepted),reset_writes=sum(x[1] for x in accepted))
def validate(directory,end_tick):
 directory=Path(directory);rows=[];hashes={}
 for name,header in [('intents.csv',['time_ps','reset','we','address','data']),('accepted-writes.csv',['time_ps','reset','address','data','valid'])]:
  path=directory/name
  with path.open(encoding='ascii',newline='') as stream:
   reader=csv.reader(stream);assert next(reader)==header;values=[tuple(map(int,row)) for row in reader]
  rows.append(values);hashes[name]=hashlib.sha256(path.read_bytes()).hexdigest()
 result=reconcile(*rows,end_tick);result['sha256']=hashes;return result
