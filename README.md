# checkurls.sh
Check a list of URLs from file urllist.txt with a bashscript to get the HTTP-status, also detect redirect loops.
URLs are checked in parallel streams, at the end a summary per HTTP status code is printed.

## How to use:
* Create a file called urllist.txt and place it in the same folder as the script
* The file should contain a URL per line (empty lines and Windows line endings are ignored)
* Alter the variable SAFE_STATUSCODES according to your needs (i've removed 301 to detect redirect loops)
* Run the script from bash:

```bash
./checkurls.sh            # default: 10 parallel streams
./checkurls.sh -s 20      # 20 parallel streams
./checkurls.sh -s 1       # sequential, output in the order of urllist.txt
STREAMS=5 ./checkurls.sh  # set streams via environment variable
./checkurls.sh -h         # show help
```

## Parallel streams
* The number of streams is the number of URLs checked at the same time (default: 10, see `STREAMS` in `SetParam`)
* `-s` overrides the environment variable `STREAMS`, which overrides the default
* With more than 1 stream the output order differs from the order in urllist.txt
* Be careful with high values when all URLs point to the same server: rate limits or a WAF may block you, start with 5-10

## Summary
At the end of each run a summary is printed and appended to Script_Monitor.log:

```
===================== SUMMARY (13-10-2026_15.46.33) =====================
Checked with 10 parallel stream(s)
Code      Count   Percent   Description
-------------------------------------------------------------
000           1     6.25%   No response (connection error, timeout, DNS or too many redirects)
200          12    75.00%   OK
301           1     6.25%   Moved Permanently
404           2    12.50%   Not Found
-------------------------------------------------------------
UP           12    75.00%
DOWN          4    25.00%
Total        16   100.00%
=============================================================
```

UP/DOWN are based on SAFE_STATUSCODES.
