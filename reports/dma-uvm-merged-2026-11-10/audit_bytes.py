"""Read-only Git/raw/fresh-checkout byte audit for the DMA milestone bundle."""
import argparse,hashlib,json,subprocess,urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote
BASE='reports/dma-uvm-merged-2026-11-10/'
def sha(b):return hashlib.sha256(b).hexdigest()
def git(repo,*args,input=None):return subprocess.check_output(['git','-C',str(repo),*args],input=input)
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repository',type=Path,required=True);ap.add_argument('--revision',required=True)
    ap.add_argument('--checkout-false',type=Path,required=True);ap.add_argument('--checkout-true',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
    assert not a.output.exists()
    for clone,mode in ((a.checkout_false,'false'),(a.checkout_true,'true')):
        assert git(clone,'rev-parse','HEAD').decode().strip()==a.revision
        assert git(clone,'config','--get','core.autocrlf').decode().strip()==mode
        assert not git(clone,'status','--porcelain').strip()
    manifest=json.loads(git(a.repository,'show',a.revision+':'+BASE+'CAPTURE_MANIFEST.json'))
    wave=json.loads(git(a.repository,'show',a.revision+':'+BASE+'waveforms/MANIFEST.json'))
    paths=[BASE+r['path'] for r in manifest['files']]
    for f in wave['figures']:paths.extend([BASE+'waveforms/'+f['figure'],BASE+'waveforms/'+f['metadata']])
    paths=list(dict.fromkeys(paths))
    # Batch Git reads preserve bytes and avoid spawning one process per artifact.
    payload=''.join(a.revision+':'+p+'\n' for p in paths).encode()
    raw=git(a.repository,'cat-file','--batch',input=payload);position=0;blobs={}
    for p in paths:
        end=raw.index(b'\n',position);header=raw[position:end].decode().split();assert header[1]=='blob'
        size=int(header[2]);position=end+1;blobs[p]=raw[position:position+size];position+=size
        assert raw[position:position+1]==b'\n';position+=1
    assert position==len(raw)
    attrs=git(a.checkout_true,'check-attr','text','--stdin',input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
    assert len(attrs)==len(paths) and all(line.endswith(': text: unset') for line in attrs)
    for p,b in blobs.items():assert b==(a.checkout_false/p).read_bytes()==(a.checkout_true/p).read_bytes(),p
    captures=[]
    for r in manifest['files']:
        p=BASE+r['path'];assert sha(blobs[p])==r['sha256'] and len(blobs[p])==r['bytes']
        if p.endswith('.vcd'):captures.append((p,r))
    def download(item):
        p,r=item;url=f'https://raw.githubusercontent.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/{a.revision}/{quote(p)}'
        with urllib.request.urlopen(url,timeout=45) as response:data=response.read()
        assert data==blobs[p],p
        return dict(path=p,original_sha256=r['sha256'],git_blob_sha256=sha(blobs[p]),public_raw_sha256=sha(data),
            both_checkout_sha256=sha((a.checkout_false/p).read_bytes()),bytes=len(data),crlf_count=data.count(b'\r\n'),raw_url=url)
    rows=[download(item) for item in captures]
    for f in wave['figures']:
        p=(a.checkout_false/BASE/'waveforms'/f['source_relative_path']).resolve().relative_to(a.checkout_false.resolve()).as_posix()
        digest=sha(blobs[p]);metadata=json.loads(blobs[BASE+'waveforms/'+f['metadata']])
        assert digest==f['source_sha256']==f['captured_sha256']==metadata['source_sha256']==metadata['captured_sha256']
        assert digest in blobs[BASE+'waveforms/'+f['figure']].decode()
    assert len(wave['figures'])==3
    report=dict(status='PASS',evidence_revision=a.revision,policy='Original capture bytes with scoped -text; no newline conversion',
        checked_artifacts=len(manifest['files']),vcd_count=len(rows),figure_count=len(wave['figures']),vcds=rows,
        audit_script_sha256=sha(Path(__file__).read_bytes()))
    a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='vcds'}))
if __name__=='__main__':main()
