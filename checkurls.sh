#!/bin/bash
#bash to check url status.
#set -x; # Enable this to enable debug mode.
#clear # Enable this to clear your screen after each run.

# What: Check URLs with their statuses and report it to an email address
# How to: Create a file named 'urllist.txt' and run this script.
#
# 2022-01-22 ChangeLog
# Removed 301 from SAFE Status Code and added follow Link and max-redirs to detect redirect loops
#
# 2026-10-13 ChangeLog
# Added summary per status code and parallel streams (STREAMS variable or -s option)
#
# Usage: ./checkurls.sh [-s STREAMS]
#   -s STREAMS  Number of URLs checked in parallel (default: 10), also settable via env STREAMS=20 ./checkurls.sh

SetParam() {
export URLFILE="urllist.txt"
# TIME is set once per run, so all workers use the same timestamp
export TIME="${TIME:-`date +%d-%m-%Y_%H.%M.%S`}"
# Number of parallel streams (URLs checked at the same time), override with -s or env STREAMS
export STREAMS="${STREAMS:-10}"

# Change Status codes here - eg. remove 301 redirects 
SAFE_STATUSCODES=( 200 201 202 203 204 205 206 207 208 226 401)
export STATUS_UP=`echo -e "\E[32m[ RUNNING ]\E[0m"`
export STATUS_DOWN=`echo -e "\E[33m[ DOWN ]\E[0m"`
export MAIL_TO="please-change-your@email-address-here.com"
export SCRIPT_LOG="Script_Monitor.log"
}

URL_Status() {

SetParam
export CODES_FILE=$(mktemp)
# Remove empty lines and Windows line endings, then check the URLs in $STREAMS parallel streams.
# Note: with more than 1 stream the output order differs from the order in $URLFILE.
grep -v '^[[:space:]]*$' "$URLFILE" | tr -d '\r' | tr '\n' '\0' | xargs -0 -n 1 -P "$STREAMS" bash -c 'Check_URL "$1"' _ |
while IFS=$'\t' read -r next STATUS_CODE
do
# First field of STATUS_CODE is the plain HTTP code, the rest are the URLs
HTTP_CODE=${STATUS_CODE%% *}
echo "At $TIME: $next url status returned $STATUS_CODE : $(Status_Text $HTTP_CODE)"
echo "$HTTP_CODE" >> "$CODES_FILE"

URL_SafeStatus $HTTP_CODE

done

Print_Summary "$CODES_FILE"
rm -f "$CODES_FILE"

}

Status_Text() {
# Returns the description for a HTTP status code
case $1 in
000) echo "No response (connection error, timeout, DNS or too many redirects)" ;;
100) echo "Continue" ;;
101) echo "Switching Protocols" ;;
102) echo "Processing (WebDAV) (RFC 2518)" ;;
103) echo "Checkpoint" ;;
122) echo "Request-URI too long" ;;
200) echo "OK" ;;
201) echo "Created" ;;
202) echo "Accepted" ;;
203) echo "Non-Authoritative Information" ;;
204) echo "No Content" ;;
205) echo "Reset Content" ;;
206) echo "Partial Content" ;;
207) echo "Multi-Status (WebDAV) (RFC 4918)" ;;
208) echo "Already Reported (WebDAV) (RFC 5842)" ;;
226) echo "IM Used (RFC 3229)" ;;
300) echo "Multiple Choices" ;;
301) echo "Moved Permanently" ;;
302) echo "Found" ;;
303) echo "See Other" ;;
304) echo "Not Modified" ;;
305) echo "Use Proxy" ;;
306) echo "Switch Proxy" ;;
307) echo "Temporary Redirect (since HTTP/1.1)" ;;
308) echo "Resume Incomplete" ;;
400) echo "Bad Request" ;;
401) echo "Unauthorized" ;;
402) echo "Payment Required" ;;
403) echo "Forbidden" ;;
404) echo "Not Found" ;;
405) echo "Method Not Allowed" ;;
406) echo "Not Acceptable" ;;
407) echo "Proxy Authentication Required" ;;
408) echo "Request Timeout" ;;
409) echo "Conflict" ;;
410) echo "Gone" ;;
411) echo "Length Required" ;;
412) echo "Precondition Failed" ;;
413) echo "Request Entity Too Large" ;;
414) echo "Request-URI Too Long" ;;
415) echo "Unsupported Media Type" ;;
416) echo "Requested Range Not Satisfiable" ;;
417) echo "Expectation Failed" ;;
500) echo "Internal Server Error" ;;
501) echo "Not Implemented" ;;
502) echo "Bad Gateway" ;;
503) echo "Service Unavailable" ;;
504) echo "Gateway Timeout" ;;
505) echo "HTTP Version Not Supported" ;;
*) echo "Unknown status code" ;;
esac
}

Print_Summary() {
# Prints count and percentage of every returned HTTP status code
local codes_file="$1"
local total
total=$(grep -c . "$codes_file")
echo ""
echo "===================== SUMMARY ($TIME) ====================="
echo "Checked with $STREAMS parallel stream(s)"
if [ "$total" -eq 0 ] ; then
echo "No URLs checked."
return
fi
printf "%-6s %8s %9s   %s\n" "Code" "Count" "Percent" "Description"
echo "-------------------------------------------------------------"
sort "$codes_file" | uniq -c | sort -k2,2n | while read -r count code
do
printf "%-6s %8d %8s%%   %s\n" "$code" "$count" "$(awk -v c="$count" -v t="$total" 'BEGIN { printf "%.2f", c*100/t }')" "$(Status_Text $code)"
done
echo "-------------------------------------------------------------"
local up=0 code
while read -r code
do
for safestatus in ${SAFE_STATUSCODES[@]}
do
if [ "$code" = "$safestatus" ] ; then up=$((up+1)); break; fi
done
done < "$codes_file"
local down=$((total-up))
printf "%-6s %8d %8s%%\n" "UP" "$up" "$(awk -v c="$up" -v t="$total" 'BEGIN { printf "%.2f", c*100/t }')"
printf "%-6s %8d %8s%%\n" "DOWN" "$down" "$(awk -v c="$down" -v t="$total" 'BEGIN { printf "%.2f", c*100/t }')"
printf "%-6s %8d %8s%%\n" "Total" "$total" "100.00"
echo "============================================================="
}

Check_URL() {
# Checks a single URL, runs in its own process (one per stream).
# Prints one line "<URL><TAB><STATUS_CODE>", which is written at once and therefore not mixed up with other streams.
local STATUS_CODE
# Added %{url} for requested URL and  %{url_effective for target URL, in case of broken rewrites, chanted http_code to response_code
STATUS_CODE=`curl -k -L --max-redirs 10 --output /dev/null --silent --head --write-out '%{response_code} %{url} %{url_effective}' "$1"`
# If you want to set a timeout then add --max-time 15, here 15 is 15seconds
printf '%s\t%s\n' "$1" "$STATUS_CODE"
}

URL_SafeStatus() {
flag=0
for safestatus in ${SAFE_STATUSCODES[@]}
do
#echo "got Value of STATUS CODE= $1";
#echo "Reading Safe Code= $safestatus";
if [ $1 -eq $safestatus ] ; then

echo "At $TIME: Status Of URL $next = $STATUS_UP $STATUS_CODE";
flag=1
break;
fi
done

if [ $flag -ne 1 ] ; then
echo "At $TIME: Status Of URL $next = $STATUS_DOWN $STATUS_CODE" | Mail_Admin $TIME $next
#break;
fi

}



# Uncomment here to send email on every down URL!
#
# Mail_Admin() {
# SetParam
# echo "At $1 URL $2 is DOWN!!" | mailx -s " Application URL: $2 DOWN!!!" $MAIL_TO
# }

# Comment here to send send email on every down URL!
Mail_Admin() {
SetParam
# Remove $STATUS_CODE here, if you just want the plain DOWN message without extended status results
echo "At $1 URL $next is DOWN!! $STATUS_CODE"
 }

Send_Log() {
SetParam
if [ -f $SCRIPT_LOG ] ; then
mailx -s "$0 Script All Url Check Log Details Till $TIME" $MAIL_TO < $SCRIPT_LOG
else
echo "$SCRIPT_LOG NOT FOUND!!"
fi
}

Main_Menu() {

URL_Status

}
Usage() {
echo "Usage: $0 [-s STREAMS]"
echo "  -s STREAMS  Number of URLs checked in parallel (default: 10)"
echo "  -h          Show this help"
}

# Make functions available for the parallel worker processes started by xargs
export -f Check_URL

while getopts "s:h" opt
do
case $opt in
s) STREAMS="$OPTARG" ;;
h) Usage; exit 0 ;;
*) Usage; exit 1 ;;
esac
done

SetParam
case "$STREAMS" in
''|*[!0-9]*|0) echo "Invalid number of streams: '$STREAMS' (must be a positive integer)"; Usage; exit 1 ;;
esac
Main_Menu | tee -a $SCRIPT_LOG
Send_Log
