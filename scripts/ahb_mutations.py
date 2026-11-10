"""Separately compiled mutations; locked checkout is never edited."""
import difflib,hashlib
from pathlib import Path
def prepare(original,dest,kind,revision):
    b=Path(original).read_bytes();text=b.decode();modified=text
    replacements={
      'live_address':('memory[index_q] <= HWDATA;','memory[HADDR[5:2]] <= HWDATA;'),
      'address_phase_data':('memory[index_q] <= HWDATA;','memory[index_q] <= bad_address_data;'),
      'read_data':('memory[index_q] :','(memory[index_q] ^ 32\'h00000001) :'),
      'invalid_write':('if(transfer_q && write_q && !error_q)','if(transfer_q && write_q)'),
      'wait_advance':('else if(HREADY)','else if(1\'b1)'),
      'short_error':('assign HREADYOUT = response_state != RESP_ERROR_WAIT;','assign HREADYOUT = 1\'b1;'),
      'missing_error':('assign HRESP = response_state != RESP_OK;','assign HRESP = 1\'b0;'),
    }
    a,c=replacements[kind];assert text.count(a)==1;modified=modified.replace(a,c)
    if kind=='address_phase_data':
        anchor='integer      i;';assert modified.count(anchor)==1
        modified=modified.replace(anchor,anchor+'\nlogic [31:0] bad_address_data;\nalways @(posedge HCLK) if(HREADY) bad_address_data <= HWDATA;')
    dest.mkdir();p=dest/'design.sv';p.write_bytes(modified.encode())
    patch=''.join(difflib.unified_diff(text.splitlines(True),modified.splitlines(True),fromfile='locked/rtl/design.sv',tofile='disposable/rtl/design.sv'))
    (dest/'mutation.diff').write_bytes(patch.encode())
    return p,dict(kind=kind,source_revision=revision,locked_sha256=hashlib.sha256(b).hexdigest(),compiled_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),patch_sha256=hashlib.sha256(patch.encode()).hexdigest(),checkout_modified=False)
