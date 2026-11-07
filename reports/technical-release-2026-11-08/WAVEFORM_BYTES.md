# Technical waveform byte audit

The [machine-readable audit](waveform-byte-audit.json) covers **30 tracked
VCDs in eleven technical repositories** at the full source revisions in each
row. Public GitHub raw downloads matched all 30 Git blobs byte for byte.
Twenty-nine Git blobs use LF newlines; one earlier AXI4-Lite VCD is already
CRLF in Git. Twenty-seven existing figure metadata hashes matched the CRLF
representation of their corresponding LF Git blob; one matched its Git blob,
and two VCDs had no figure metadata. The eight latest VGA and AMBA original
simulator captures were independently present and matched their recorded
CRLF hashes.

**Byte policy:** The committed Git blob is the canonical published VCD byte
source. The simulator capture and any checkout-converted copy are separate
byte representations and have separately labelled SHA-256 values. The current
VGA and AMBA figure JSON now sets `source_sha256` to the committed LF VCD blob
and `capture_source_sha256` to the original CRLF capture. Each current SVG
caption identifies which representation was rendered. Earlier VCDs and raw
simulator logs are unchanged; the audit maps their legacy metadata without
silently rewriting old reports.

Newline conversion changes bytes and hashes, not VCD signal events or
simulation behavior. Figures illustrate selected measured traces; the
independent simulation checks and monitor logs determine PASS.
