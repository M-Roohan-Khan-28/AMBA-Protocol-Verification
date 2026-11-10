"""Exact disposable fault transforms. Never edit the locked DUT checkout."""
from pathlib import Path
import hashlib,difflib
TRANSFORMS={
 'hsync':("h_count >= 10'd656","h_count >= 10'd655"),
 'vsync':("v_count >= 10'd490","v_count >= 10'd489"),
 'frame_wrap':("v_count == 10'd524","v_count == 10'd523"),
 'divider':("clock_divider == 2'd3","clock_divider == 2'd2"),
 'scale':('frame_x = h_count[9:3];','frame_x = h_count[9:4];'),
 'row_stride':("read_address = frame_y * 13'd80 + frame_x;","read_address = frame_y * 13'd79 + frame_x;"),
 'rgb':('{pixel_data[7:5], pixel_data[7]}','{pixel_data[7:5], ~pixel_data[7]}'),
 'blank':("blue  = 4'h0;","blue  = 4'h1;"),
 'invalid_alias':("if(sram_we && sram_addr < 13'd4800)\n        sram[sram_addr] <= sram_data_in;","if(sram_we)\n        sram[sram_addr % 4800] <= sram_data_in;"),
 'clear_reset':("if(sram_we && sram_addr < 13'd4800)\n        sram[sram_addr] <= sram_data_in;", "if(reset) begin\n        for(integer fault_i=0; fault_i<4800; fault_i=fault_i+1) sram[fault_i] <= 0;\n    end else if(sram_we && sram_addr < 13'd4800)\n        sram[sram_addr] <= sram_data_in;"),
 'disabled_reset_write':("if(sram_we && sram_addr < 13'd4800)","if(sram_we && !reset && sram_addr < 13'd4800)"),
 'gated_write':("if(sram_we && sram_addr < 13'd4800)","if(sram_we && clock_divider == 2'd3 && sram_addr < 13'd4800)")}
def sha(data):return hashlib.sha256(data).hexdigest()
def prepare(source,dest,kind,revision):
 original=Path(source).read_bytes();text=original.decode('utf-8');before,after=TRANSFORMS[kind]
 assert text.count(before)==1,(kind,text.count(before));modified=text.replace(before,after)
 dest=Path(dest);dest.mkdir();p=dest/'design.sv';p.write_bytes(modified.encode())
 (dest/'mutation.diff').write_text(''.join(difflib.unified_diff(text.splitlines(True),modified.splitlines(True),fromfile='locked/design.sv',tofile='disposable/design.sv')),encoding='utf-8')
 return p,dict(kind=kind,source_revision=revision,locked_sha256=sha(original),compiled_sha256=sha(p.read_bytes()),checkout_modified=False)
