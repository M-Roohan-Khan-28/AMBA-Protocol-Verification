"""Verify this milestone's exact VCD bytes in Git, public raw and two checkouts."""
import argparse,hashlib,json,subprocess,urllib.request
from pathlib import Path
from urllib.parse import quote

def sha(data):return hashlib.sha256(data).hexdigest()
def git(repo,*args):return subprocess.check_output(['git','-C',str(repo),*args])

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repository',type=Path,required=True)
    ap.add_argument('--revision',required=True)
    ap.add_argument('--checkout-false',type=Path,required=True)
    ap.add_argument('--checkout-true',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args()
    if a.output.exists():ap.error('Use new audit output')
    base='reports/advanced-apb-2026-11-08/'
    for clone,mode in [(a.checkout_false,'false'),(a.checkout_true,'true')]:
        assert git(clone,'rev-parse','HEAD').decode().strip()==a.revision
        assert git(clone,'config','--get','core.autocrlf').decode().strip()==mode
        assert not git(clone,'status','--porcelain').strip()
    paths=git(a.repository,'ls-tree','-r','--name-only',a.revision,'--',base).decode().splitlines()
    records=[]
    for path in paths:
        if not path.endswith('.vcd'):continue
        blob=git(a.repository,'show',a.revision+':'+path)
        url=f'https://raw.githubusercontent.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/{a.revision}/{quote(path)}'
        with urllib.request.urlopen(url,timeout=45) as r:raw=r.read()
        variants={'git_blob':blob,'public_raw':raw,'checkout_autocrlf_false':(a.checkout_false/path).read_bytes(),'checkout_autocrlf_true':(a.checkout_true/path).read_bytes()}
        hashes={name:sha(data) for name,data in variants.items()}
        assert len(set(hashes.values()))==1,(path,hashes)
        attrs=git(a.checkout_true,'check-attr','text','--',path).decode().strip()
        assert attrs.endswith(': unset'),attrs
        records.append({'path':path,'sha256':hashes,'bytes':len(blob),'crlf_count':blob.count(b'\r\n'),'lf_count':blob.count(b'\n'),'text_attribute':attrs,'raw_url':url})
    figures=[]
    for path in paths:
        if '/waveforms/adapter-' not in path or not path.endswith('.json'):continue
        m=json.loads(git(a.repository,'show',a.revision+':'+path))
        source=(a.checkout_false/Path(path).parent/m['source_relative_path']).resolve()
        rel=source.relative_to(a.checkout_false.resolve()).as_posix()
        h=sha(git(a.repository,'show',a.revision+':'+rel))
        assert h==m['source_sha256']==m['captured_sha256']
        svg=git(a.repository,'show',a.revision+':'+path[:-5]+'.svg').decode()
        assert h in svg
        figures.append({'metadata':path,'source':rel,'sha256':h,'source_representation':m['source_representation'],'start_tick':m['start_tick'],'end_tick':m['end_tick']})
    assert records and len(figures)==5
    report={'status':'PASS','audited_evidence_revision':a.revision,'audit_script_sha256':sha(Path(__file__).read_bytes()),
      'policy':'Capture bytes committed with -text; no transformation; original capture hash equals committed hash',
      'vcd_count':len(records),'figure_count':len(figures),'vcds':records,'figures':figures}
    a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':'PASS','vcd_count':len(records),'figure_count':len(figures),'revision':a.revision}))
if __name__=='__main__':main()
