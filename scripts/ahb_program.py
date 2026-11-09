"""Deterministic public-pin schedules. No DUT model or internal memory access.

Request intents are separate records, sent before drive; the SV scoreboard builds
expected memory from those intents. This scheduler derives only timing/counts.
"""
def word(i,salt=0):
    x=(0x28A6BEEF ^ (i*0x9e3779b9) ^ salt)&0xffffffff
    x^=x<<13;x&=0xffffffff;x^=x>>17;x^=x<<5
    return x&0xffffffff
def invalid(r):return r['addr']>60 or r['addr']%4 or r['size']!=2
class Program:
    def __init__(self,name):
        self.name=name;self.rows=[];self.next_id=1;self.offers={};self.pending=None;self.phase=0;self.last=None;self.counts={k:0 for k in ('offered','accepted','success','errors','writes','reads','withdrawn','reset_accepted','reset_offered','wait_edges','pipeline_edges','resets')};self.in_reset=False
    def request(self,addr,write=0,data=None,size=2,trans=2):
        r=dict(id=self.next_id,addr=addr,write=write,data=word(self.next_id) if data is None else data,size=size,trans=trans);self.next_id+=1;return r
    def emit(self,r=None,*,offer=False,ext=1,reset=1,sel=None,trans=None,addr=None,write=None,size=None,data=None,cancel=0):
        if offer:
            assert r and r['id'] not in self.offers;self.offers[r['id']]=r;self.counts['offered']+=1
        if cancel:
            assert cancel in self.offers;self.offers.pop(cancel);self.counts['withdrawn']+=1
        dr=dict(sel=int(r is not None),trans=r['trans'] if r else 0,write=r['write'] if r else 0,size=r['size'] if r else 2,addr=r['addr'] if r else 0)
        for k,v in dict(sel=sel,trans=trans,addr=addr,write=write,size=size).items():
            if v is not None:dr[k]=v
        wd=(self.pending['data'] if self.pending and self.pending['write'] else word(len(self.rows),0x11335577)) if data is None else data
        intent=r if offer else dict(id=0,addr=0,write=0,size=0,data=0)
        self.rows.append([dr['sel'],dr['trans'],dr['write'],dr['size'],dr['addr'],wd,ext,reset,intent['id'],intent['addr'],intent['write'],intent['size'],intent['data'],cancel])
        global_ready=ext and self.phase!=1
        if not reset:
            if not self.in_reset:
                self.counts['resets']+=1;self.counts['reset_accepted']+=int(self.pending is not None);self.counts['reset_offered']+=len(self.offers)
            self.pending=None;self.offers.clear();self.phase=0;self.in_reset=True
        else:
            self.in_reset=False
            if not global_ready:self.counts['wait_edges']+=1
            if self.phase==1:self.phase=2
            elif global_ready:
                prior=self.pending
                if prior:
                    if invalid(prior):self.counts['errors']+=1
                    else:
                        self.counts['success']+=1;self.counts['writes' if prior['write'] else 'reads']+=1
                self.pending=None;self.phase=0
                if dr['sel'] and dr['trans']>=2:
                    assert r and r['id'] in self.offers,(self.name,dr,self.offers)
                    self.pending=self.offers.pop(r['id']);self.counts['accepted']+=1
                    if prior:self.counts['pipeline_edges']+=1
                    if invalid(r):self.phase=1
        self.last=r
    def issue(self,r):self.emit(r,offer=True)
    def drain(self):
        while self.pending:self.emit()
    def reset(self):self.emit(reset=0);self.emit(reset=0);self.emit()
    def seed(self):
        for i in range(16):self.issue(self.request(4*i,1,word(i,0x55667788),trans=2 if i==0 else 3))
        self.drain()
    def readback(self):
        for i in range(16):self.issue(self.request(4*i,0,trans=2 if i==0 else 3))
        self.drain()
    def done(self):
        self.drain();self.emit();assert not self.offers
        c=self.counts;assert c['offered']==c['accepted']+c['withdrawn']+c['reset_offered'];assert c['accepted']==c['success']+c['errors']+c['reset_accepted']
        return self

def build(case):
    name=case['name'];kind=case['kind'];p=Program(name);p.reset()
    if kind=='smoke':
        p.issue(p.request(0,1,0x1265abcd));p.issue(p.request(0));p.drain();return p.done()
    p.seed()
    if kind=='all_words':
        p.readback()
        for i in range(15,-1,-1):p.issue(p.request(i*4,1,word(i,0xf00d1234),trans=3))
    elif kind=='pipeline':
        dirs=case['directions'];a=8;b=8 if case['same'] else 44
        p.issue(p.request(a,int(dirs[0]=='W'),0x55aa01fe))
        p.issue(p.request(b,int(dirs[1]=='W'),0x9ac35678,trans=3));p.drain()
    elif kind=='ignored':
        for wr in (0,1):
            p.issue(p.request(12,wr,0xa5c39966));p.emit(sel=case['sel'],trans=case['trans'],addr=52,write=1-wr,data=0xa5c39966);p.emit()
    elif kind=='wait':
        first=p.request(8,case['write'],0x7a1359b0);nxt=p.request(44,1,0xa1887766,trans=3)
        p.issue(first)
        for n in range(case['waits']):p.emit(nxt,offer=n==0,ext=0)
        p.emit(nxt);p.drain()
    elif kind=='wait_exception':
        p.issue(p.request(0,0));nxt=p.request(24,case.get('write',1),0x6789abcd,trans=case['next'])
        p.emit(sel=1,trans=case['initial'],addr=24,write=0,ext=0,data=0x88880001)
        if case['initial']==0:p.emit(sel=0,trans=0,addr=52,write=1,ext=0,data=0x88880002)
        if case['next']>=2:
            p.emit(nxt,offer=True,ext=0,data=0x99990001);p.emit(nxt,data=0x99990002);p.drain()
        else:p.emit(sel=0,trans=0,addr=60,write=1,ext=0,data=0x99990001);p.emit(data=0x99990002)
    elif kind=='invalid':
        bad=p.request(case['addr'],case.get('write',1),0xdeada55a,size=case.get('size',2));nxt=p.request(40,1,0xbad0babe)
        p.issue(bad);p.emit(nxt,offer=True)
        if case.get('continue',False):
            for _ in range(case.get('hold',0)):p.emit(nxt,ext=0)
            p.emit(nxt);p.drain()
        else:
            p.emit(cancel=nxt['id'],ext=0)
            for _ in range(case.get('hold',0)):p.emit(ext=0)
            p.emit();p.drain()
        # Protected memory is read before any subsequent write or reset.
        p.readback();p.issue(p.request(36,1,0x46789abc));p.drain()
    elif kind=='reset':
        mode=case['mode']
        if mode!='idle':
            r=p.request(4 if mode in ('normal','write_wait') else 1,1,0xfadebad0);p.issue(r)
            if mode=='write_wait':p.emit(p.request(48,1,0x12345678),offer=True,ext=0)
            if mode=='error_finish':p.emit(ext=0);p.emit(ext=0)
        p.reset();p.readback();p.issue(p.request(56,1,0xcafebeed));p.drain()
    else:raise ValueError(kind)
    p.readback();return p.done()

def serialize(programs):
    rows=[]
    for p in programs:
        rows.append(p.name+' 1 '+' '.join(['0']*14))
        rows.extend(p.name+' 0 '+' '.join(str(x) for x in r) for r in p.rows)
        rows.append(p.name+' 2 '+' '.join(['0']*14))
    return '\n'.join(rows)+'\n'
