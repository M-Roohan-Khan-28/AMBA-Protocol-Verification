$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\cache-uvm-source-new
git -C C:\short\cache-uvm-source-new checkout --detach 9c74c35e0c2616a09af8824d2d85754738b5303a
& $python C:\short\cache-uvm-source-new\scripts\run_cache_uvm.py --expected-env-sha 9c74c35e0c2616a09af8824d2d85754738b5303a --output C:\short\cache-uvm-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required cache milestone failed or was blocked' }
