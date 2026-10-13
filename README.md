# checkurls.sh
Check a list of URLs from file urllist.txt with a bashscript to get the HTTP-status, also detect redirect loops.
URLs are checked in parallel streams with a progress bar, at the end a summary per HTTP status code is printed.

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
./checkurls.sh -q         # quiet: only progress bar and summary on screen, results go to the log
./checkurls.sh -n         # no progress bar
./checkurls.sh -h         # show help
```

## Parallel streams
* The number of streams is the number of URLs checked at the same time (default: 10, see `STREAMS` in `SetParam`)
* `-s` overrides the environment variable `STREAMS`, which overrides the default
* With more than 1 stream the output order differs from the order in urllist.txt
* Be careful with high values when all URLs point to the same server: rate limits or a WAF may block you, start with 5-10

## Progress bar
While running, a progress bar is shown at the bottom of the terminal:

```
[################------------------------]  40% (1600/4000) elapsed 00:02:10 ETA 00:03:15
```

* It shows done/total URLs, elapsed time and the estimated remaining time (ETA)
* The bar is written to stderr and is not part of Script_Monitor.log
* It is only shown when running in a terminal, so cron jobs or redirected output (`2>file`) stay clean
* Use `-n` to disable it, use `-q` to hide the single URL results on screen (useful for long lists)

## Summary
At the end of each run a summary is printed and appended to Script_Monitor.log:

```
===================== SUMMARY (13-10-2026_15.46.33) =====================
Checked with 10 parallel stream(s), duration 00:00:02
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
