"""Independent inventory-to-result reconciliation for the bounded programmed DMA."""
def plan(src,dst,length):
    if not length:return []
    if length>4096 or src%8 or dst%8 or src+length>2**32 or dst+length>2**32 or (src<dst+length and dst<src+length):return []
    offset=0;bursts=[]
    while offset<length:
        size=min(128,length-offset,4096-(src+offset)%4096,4096-(dst+offset)%4096)
        bursts.append((size+7)//8);offset+=size
    return bursts

def validate(case,r):
    def check(test,why):
        if not test:raise ValueError(case['name']+': '+why)
    check(r['name']==case['name'],'case identity')
    reset=case['reset_kind'] in (1,2,3);error=bool(case['expected_error']);chain=bool(case['chain'])
    check(r['commands']==1+int(reset or error or chain),'accepted command count')
    check(r['reset_cancellations']==int(reset),'reset cancellation count')
    check(r['terminals']==r['commands']-r['reset_cancellations'],'terminal/reset reconciliation')
    check(r['errors']==int(error) and r['successes']==r['terminals']-r['errors'],'terminal outcomes')
    check(r['acknowledgements']==1+int(error),'acknowledgements (status reads are not completions)')
    check(r['control_cancelled']==int(case['reset_kind'] in (4,5)),'partial control cancellation')
    check(r['control_rejected']==(24 if case['csr_tests']==1 else 6 if case['csr_tests']==2 else 0),'rejected control writes')
    check(r['comparisons']>0 and r['csr_reads']>=7,'executed comparisons/CSR reads')
    bursts=plan(case['src'],case['dst'],case['length']);ar=aw=b=len(bursts);rb=wb=sum(bursts)
    if case['expected_error']==1:ar=aw=b=rb=wb=0
    elif case['expected_error']==2:
        i=max(0,case['read_error_burst']);ar=i+1;aw=b=i;wb=sum(bursts[:i]);rb=sum(bursts[:i+1])
        if case['malformed']==3:rb=1
    elif case['expected_error']==3:
        i=max(0,case['write_error_burst']);ar=aw=b=i+1;rb=wb=sum(bursts[:i+1])
    if reset:
        if case['reset_kind']==1:ar=1;aw=b=wb=0;rb=r['cancelled_r_beats'];check(r['cancelled_ar']==1 and rb>=2,'read cancellation stage')
        elif case['reset_kind']==2:
            ar=1+r['cancelled_ar'];aw=b=1;rb=bursts[0]+r['cancelled_r_beats'];wb=bursts[0];check(r['cancelled_b_pending']==0,'accepted B before reset')
        else:
            ar=aw=1;b=0;rb=wb=bursts[0];check(r['cancelled_b_pending']==1 and r['cancelled_aw']==1,'committed write awaiting B at reset')
    if reset or error or chain:ar+=1;aw+=1;b+=1;rb+=2;wb+=2
    check((r['ar'],r['aw'],r['r_beats'],r['w_beats'],r['b'])==(ar,aw,rb,wb,b),'burst/beat/response totals')
    check(r['memory_commits']==aw,'complete buffered write events')
    if not reset and not error and bursts:
        if case['order']==0:check(r['aw_first']==ar,'address-first observation')
        if case['order'] in (1,2):check(r['w_first']==ar,'data-first observation')
        if case['order']==2:check(r['all_w_before_aw']==ar,'all write data before address')
        if case['order']==3:check(r['simultaneous']==ar,'same-edge AW/first-W observation')
