"""Audit actual functional VCDs for the chosen bounded INCR/independent stimulus convention."""
import sys,bisect,json,hashlib,argparse
from pathlib import Path
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--repository',type=Path,required=True);ap.add_argument('--old-run',type=Path,required=True);ap.add_argument('--corrected-run',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
args=ap.parse_args();assert not args.output.exists()
sys.path.insert(0,str(args.repository/'tools'));import vcd_to_svg
HERE=Path(__file__).resolve().parent

def inspect(folder):
 root=Path(folder);cap=root/'functional/capture.vcd';trace=vcd_to_svg.parse_vcd(cap);r=json.loads((root/'results.json').read_text())
 def events(n):return trace.events[trace.signals['ahb_uvm_top.bus.'+n].code]
 def val(n,t):
  xs=events(n);i=bisect.bisect_left([t for t,_ in xs],t)-1
  return int(xs[i][1],2) if i>=0 else 0
 prev=None;issues=[];accepted=0;seq=0;busy=0
 for t,v in events('clk'):
  if v!='1':continue
  if not val('reset_n',t):prev=None;continue
  ready=val('ready',t);sel=val('sel',t);tr=val('trans',t);current={n:val(n,t) for n in ('addr','write','size')}
  if sel and (tr==1 or (tr==3 and ready)):
   if tr==1:busy+=1
   else:seq+=1
   if prev is None or current['addr']!=prev['addr']+4 or current['write']!=prev['write'] or current['size']!=prev['size']:
    issues.append(dict(tick=t,trans=tr,current=current,prior_accepted=prev))
  if ready:
   if sel and tr>=2:accepted+=1;prev=current
   elif not sel or tr==0:prev=None
 return dict(source_revision=r['source_revision'],capture_path=str(cap),capture_sha256=hashlib.sha256(cap.read_bytes()).hexdigest(),accepted=accepted,seq_acceptances=seq,busy_samples=busy,violations=issues)
if __name__=='__main__':
 old=inspect(args.old_run);new=inspect(args.corrected_run);assert old['violations'] and not new['violations']
 report=dict(command=[sys.executable,*sys.argv],status='PASS',purpose='Stimulus convention review, not a full AHB burst checker or coverage metric',assumption='SEQ/BUSY examples continue an incrementing word sequence; independent operations use NONSEQ; endpoint has no HBURST port',old=old,corrected=new,old_result='Endpoint checks passed but stimulus failed this sequencing audit',corrected_result='Zero sequencing violations in actual corrected functional capture',script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
 args.output.write_bytes((json.dumps(report,indent=2)+'\n').encode());print('Old violations',len(old['violations']),'corrected',len(new['violations']))
