"""Audit exact simulator bytes in Git, public raw, and two fresh checkouts."""
import argparse,hashlib,json,subprocess,urllib.request
from pathlib import Path
from urllib.parse import quote

def sha(b):return hashlib.sha256(b).hexdigest()
def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args])
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repository',type=Path,required=True)
    ap.add_argument('--revision',required=True)
    ap.add_argument('--checkout-false',type=Path,required=True)
    ap.add_argument('--checkout-true',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args();base='reports/axil-uvm-2026-11-08/'
    assert not a.output.exists()
    for clone,mode in [(a.checkout_false,'false'),(a.checkout_true,'true')]:
        assert git(clone,'rev-parse','HEAD').decode().strip()==a.revision
        assert git(clone,'config','--get','core.autocrlf').decode().strip()==mode
        assert not git(clone,'status','--porcelain').strip()
    manifest=json.loads(git(a.repository,'show',a.revision+':'+base+'CAPTURE_MANIFEST.json'))
    captures=[]
    for row in manifest['files']:
        path=base+row['path'];blob=git(a.repository,'show',a.revision+':'+path)
        assert sha(blob)==row['sha256']
        assert blob==(a.checkout_false/path).read_bytes()==(a.checkout_true/path).read_bytes()
        assert git(a.checkout_true,'check-attr','text','--',path).decode().strip().endswith(': unset')
        if not path.endswith('.vcd'):continue
        url=f'https://raw.githubusercontent.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/{a.revision}/{quote(path)}'
        with urllib.request.urlopen(url,timeout=45) as r:raw=r.read()
        assert raw==blob
        captures.append(dict(path=path,original_sha256=row['sha256'],git_blob_sha256=sha(blob),public_raw_sha256=sha(raw),
            both_checkout_sha256=sha((a.checkout_false/path).read_bytes()),bytes=len(blob),crlf_count=blob.count(b'\r\n'),raw_url=url))
    wave=json.loads(git(a.repository,'show',a.revision+':'+base+'waveforms/MANIFEST.json'))
    for figure in wave['figures']:
        rel=(a.checkout_false/base/'waveforms'/figure['source_relative_path']).resolve().relative_to(a.checkout_false.resolve()).as_posix()
        digest=sha(git(a.repository,'show',a.revision+':'+rel))
        assert digest==figure['source_sha256']==figure['captured_sha256']
        assert digest in git(a.repository,'show',a.revision+':'+base+'waveforms/'+figure['figure']).decode()
    assert len(wave['figures'])==8 and len(captures)>=3
    report=dict(status='PASS',evidence_revision=a.revision,policy='Capture bytes committed with scoped -text; no newline conversion',
      checked_artifacts=len(manifest['files']),vcd_count=len(captures),figure_count=len(wave['figures']),vcds=captures,
      audit_script_sha256=sha(Path(__file__).read_bytes()))
    a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='vcds'}))
if __name__=='__main__':main()
