# checkurls.sh
Check a list of URLs from file urllist.txt with a bashscript to get the HTTP-status, also detect redirect loops.

## How to use:
* Create a file called urllist.txt and place it in them folder as the script
* The file should contain a URL per line
* Alter the variable SAFE_STATUSCODES according to your needs (i've removed 301 to detect redirect loops)
* run script from bash
