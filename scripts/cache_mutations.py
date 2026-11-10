"""Exact disposable mutations of the locked original; never edit its checkout."""
from pathlib import Path
from advanced_sim import digest
def prepare(source,dest,kind,revision):
 original=source.read_text();text=original
 substitutions={
  'wrong_way':('[way_select][index]','[!way_select][index]'),
  'wrong_set':('[way_select][index]','[way_select][index ^ 2\'b01]'),
  'wrong_tag':('<= tag;','<= tag ^ 3\'b001;'),
  'corrupted_data':('<= data_in;','<= data_in ^ 8\'h01;'),
  'missing_reset':("valid[i][j]    <= 1'b0;","valid[i][j]    <= valid[i][j];"),
  'forbidden_reset_write':('if(reset)','if(reset && !write)'),
  'false_hit':("hit      = 1'b0;","hit      = 1'b1;")}
 if kind=='wrong_priority':
  text=text.replace('valid[0][index]','valid[TEMP][index]').replace('tag_mem[0][index]','tag_mem[TEMP][index]').replace('data_mem[0][index]','data_mem[TEMP][index]')
  text=text.replace('[1][index]','[0][index]').replace('[TEMP][index]','[1][index]')
 else:
  old,new=substitutions[kind];assert old in text;text=text.replace(old,new)
 assert text!=original
 dest.mkdir();target=dest/'design.sv';target.write_text(text,encoding='utf-8',newline='\n')
 return target,dict(kind=kind,source_revision=revision,locked_sha256=digest(source),compiled_sha256=digest(target),checkout_modified=False)
