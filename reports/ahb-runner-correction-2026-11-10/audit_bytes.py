"""Read-only byte audit of the separate AHB runner correction evidence."""
import argparse,hashlib,json,subprocess,urllib.request
from pathlib import Path
from urllib.parse import quote
PREFIX='reports/ahb-runner-correction-2026-11-10/'
def sha(b):return hashlib.sha256(b).hexdigest()
def git(repo,*args,input=None):return subprocess.check_output(['git','-C',str(repo),*args],input=input)
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--repository',type=Path,required=True);ap.add_argument('--revision',required=True)
 ap.add_argument('--checkout-false',type=Path,required=True);ap.add_argument('--checkout-true',type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();assert not a.output.exists()
 for folder,mode in ((a.checkout_false,'false'),(a.checkout_true,'true')):
  assert git(folder,'rev-parse','HEAD').decode().strip()==a.revision
  assert git(folder,'config','--get','core.autocrlf').decode().strip()==mode
  assert not git(folder,'status','--porcelain')
 manifest=json.loads(git(a.repository,'show',a.revision+':'+PREFIX+'CAPTURE_MANIFEST.json'))
 paths=[PREFIX+f['path'] for f in manifest['files']]
 raw=git(a.repository,'cat-file','--batch',input=''.join(a.revision+':'+p+'\n' for p in paths).encode());position=0;blobs={}
 for p in paths:
  end=raw.index(b'\n',position);header=raw[position:end].decode().split();assert header[1]=='blob'
  size=int(header[2]);position=end+1;blobs[p]=raw[position:position+size];position+=size
  assert raw[position:position+1]==b'\n';position+=1
 assert position==len(raw)
 attrs=git(a.checkout_true,'check-attr','text','--stdin',input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(attrs)==len(paths) and all(x.endswith(': text: unset') for x in attrs)
 captures=[]
 for f in manifest['files']:
  p=PREFIX+f['path'];b=blobs[p]
  assert b==(a.checkout_false/p).read_bytes()==(a.checkout_true/p).read_bytes()
  assert sha(b)==f['sha256'] and len(b)==f['bytes']
  if p.endswith('.vcd'):
   url=f'https://raw.githubusercontent.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/{a.revision}/{quote(p)}'
   with urllib.request.urlopen(url,timeout=45) as response:download=response.read()
   assert download==b,p
   captures.append(dict(path=p,original_sha256=f['sha256'],git_blob_sha256=sha(b),raw_sha256=sha(download),both_checkout_sha256=sha((a.checkout_false/p).read_bytes()),raw_url=url,bytes=len(b)))
 result=dict(status='PASS',revision=a.revision,checked_artifacts=len(paths),vcd_count=len(captures),vcds=captures,policy=manifest['policy'],audit_script_sha256=sha(Path(__file__).read_bytes()))
 a.output.write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps({k:v for k,v in result.items() if k!='vcds'}))
if __name__=='__main__':main()
