"""Explicit disposable RTL controls. Never modify the locked source checkout."""
import difflib,json
from pathlib import Path
from advanced_sim import digest

def prepare(original: Path, folder: Path, kind: str, source_revision: str):
    text=original.read_text()
    if kind=='csr_idle_side_effect':
        before="""if (w_strobes != 4'hF) begin
                    s_axil_bresp <= RESP_SLVERR;"""
        after=before+"""
                    if (aw_address == 0 && state == IDLE) begin
                        src_reg <= w_data;
                        $display("DMA_MUTATION_APPLIED csr_idle_side_effect SRC response=SLVERR");
                    end"""
    elif kind=='csr_busy_side_effect':
        before="""32'h00: if (state == IDLE) src_reg <= w_data;
                                 else s_axil_bresp <= RESP_SLVERR;"""
        after="""32'h00: if (state == IDLE) src_reg <= w_data;
                                 else begin
                                     s_axil_bresp <= RESP_SLVERR;
                                     src_reg <= w_data;
                                     $display("DMA_MUTATION_APPLIED csr_busy_side_effect SRC response=SLVERR");
                                 end"""
    else:raise ValueError('Unrecognized disposable mutation: '+kind)
    if text.count(before)!=1:raise ValueError('Mutation anchor is not unique')
    mutated=text.replace(before,after)
    folder.mkdir()
    path=folder/original.name;path.write_text(mutated,encoding='utf-8',newline='\n')
    patch=''.join(difflib.unified_diff(text.splitlines(True),mutated.splitlines(True),fromfile='locked/rtl/'+original.name,tofile='disposable/'+original.name))
    (folder/'mutation.diff').write_text(patch,encoding='utf-8',newline='\n')
    record=dict(kind=kind,source_revision=source_revision,locked_input=str(original),locked_sha256=digest(original),
                compiled_input=str(path),compiled_sha256=digest(path),patch_sha256=digest(folder/'mutation.diff'),
                checkout_modified=False,scope='Rejected CSR write modifies SRC; BRESP remains SLVERR; active cur_src untouched')
    (folder/'mutation.json').write_text(json.dumps(record,indent=2)+'\n')
    return path,record
