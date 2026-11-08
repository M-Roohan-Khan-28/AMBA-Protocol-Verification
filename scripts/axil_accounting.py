"""Independent result-count reconciliation; counts are not coverage."""

def validate_accounting(a, counts, adapter):
    keys = ('adapter requests completions write_requests read_requests write_completions '
            'read_completions write_cancelled read_cancelled aw_accepted w_accepted ar_accepted '
            'b_accepted r_accepted cancelled_aw cancelled_w cancelled_ar cancelled_b cancelled_r').split()
    if any(type(a.get(k)) is not int or a[k] < 0 for k in keys):
        raise ValueError('Missing/noninteger/negative accounting field')
    if a['adapter'] != adapter:
        raise ValueError('Accounting adapter mismatch')
    if counts['writes'] != a['b_accepted'] or counts['reads'] != a['r_accepted']:
        raise ValueError('Log/JSON bus response count mismatch')
    if adapter == 0:
        if counts['completed'] != counts['writes'] + counts['reads']:
            raise ValueError('Slave completion count mismatch')
        return
    equalities = [
        (a['requests'], a['write_requests'] + a['read_requests']),
        (a['completions'], a['write_completions'] + a['read_completions']),
        (a['write_requests'], a['write_completions'] + a['write_cancelled']),
        (a['read_requests'], a['read_completions'] + a['read_cancelled']),
        (a['aw_accepted'], a['write_completions'] + a['cancelled_aw']),
        (a['w_accepted'], a['write_completions'] + a['cancelled_w']),
        (a['ar_accepted'], a['read_completions'] + a['cancelled_ar']),
        (a['b_accepted'], a['write_completions'] + a['cancelled_b']),
        (a['r_accepted'], a['read_completions'] + a['cancelled_r']),
        (counts['completed'], a['completions']),
        (counts['cancelled'], a['write_cancelled'] + a['read_cancelled']),
    ]
    if any(left != right for left, right in equalities):
        raise ValueError('Bus/CPU/reset count reconciliation failed')
    if not (a['cancelled_b'] <= min(a['cancelled_aw'], a['cancelled_w']) and
            max(a['cancelled_aw'], a['cancelled_w']) <= a['write_cancelled'] and
            a['cancelled_r'] <= a['cancelled_ar'] <= a['read_cancelled']):
        raise ValueError('Impossible reset-stage accounting')
