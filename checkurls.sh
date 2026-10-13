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
# Added progress bar (-n to disable) and quiet mode (-q)
# Added CSV export of the results from the log file without a new run (-c, -a)
#
# Usage: ./checkurls.sh [-s STREAMS] [-q] [-n]
#        ./checkurls.sh -c [-a]
#   -s STREAMS  Number of URLs checked in parallel (default: 10), also settable via env STREAMS=20 ./checkurls.sh
#   -q          Quiet: show only progress bar and summary on screen (all results are still written to the log)
#   -n          No progress bar
#   -c          Convert the results of the last run in the log file to CSV, no URLs are checked
#   -a          With -c: convert all runs in the log file instead of only the last one

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
# Separator for the CSV export (-c), ";" works with Excel in German locale
export CSV_SEP=";"
}

URL_Status() {

SetParam
export CODES_FILE=$(mktemp)
local list_file total count=0 block
list_file=$(mktemp)
# Remove empty lines and Windows line endings
grep -v '^[[:space:]]*$' "$URLFILE" | tr -d '\r' > "$list_file"
total=$(wc -l < "$list_file" | tr -d ' ')
SECONDS=0
Progress_Draw 0 "$total"
# Check the URLs in $STREAMS parallel streams.
# Note: with more than 1 stream the output order differs from the order in $URLFILE.
tr '\n' '\0' < "$list_file" | xargs -0 -n 1 -P "$STREAMS" bash -c 'Check_URL "$1"' _ |
while IFS=$'\t' read -r next STATUS_CODE
do
# First field of STATUS_CODE is the plain HTTP code, the rest are the URLs
HTTP_CODE=${STATUS_CODE%% *}
echo "$HTTP_CODE" >> "$CODES_FILE"
block="$(echo "At $TIME: $next url status returned $STATUS_CODE : $(Status_Text $HTTP_CODE)"; URL_SafeStatus $HTTP_CODE)"
count=$((count+1))
# Remove progress bar, print result, redraw progress bar below it
Progress_Clear
Output "$block"
Progress_Draw "$count" "$total"
done
Progress_Finish

Print_Summary "$CODES_FILE" | tee -a "$SCRIPT_LOG"
rm -f "$CODES_FILE" "$list_file"

}

Output() {
# Writes results to the log and, if not in quiet mode, to the screen
[ "$QUIET" = 1 ] || printf '%s\n' "$1"
printf '%s\n' "$1" >> "$SCRIPT_LOG"
}

Format_Time() {
# Formats seconds as hh:mm:ss
printf '%02d:%02d:%02d' $(($1/3600)) $(($1%3600/60)) $(($1%60))
}

Progress_Draw() {
# Draws the progress bar on stderr: [#####-----]  50% (2/4) elapsed 00:00:05 ETA 00:00:05
[ "$PROGRESS" = 1 ] || return 0
local current=$1 total=$2 width=${PROGRESS_WIDTH:-40} percent filled bar empty eta="--:--:--"
[ "$total" -gt 0 ] || return 0
percent=$((current*100/total))
filled=$((current*width/total))
[ "$current" -gt 0 ] && eta=$(Format_Time $((SECONDS*(total-current)/current)))
printf -v bar '%*s' "$filled" ''
printf -v empty '%*s' "$((width-filled))" ''
printf '\r\033[K[%s%s] %3d%% (%d/%d) elapsed %s ETA %s' "${bar// /#}" "${empty// /-}" "$percent" "$current" "$total" "$(Format_Time $SECONDS)" "$eta" >&2
}

Progress_Clear() {
[ "$PROGRESS" = 1 ] || return 0
printf '\r\033[K' >&2
}

Progress_Finish() {
# Keep the final progress bar visible and move to the next line
[ "$PROGRESS" = 1 ] || return 0
printf '\n' >&2
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
echo "Checked with $STREAMS parallel stream(s), duration $(Format_Time $SECONDS)"
if [ "$total" -eq 0 ] ; then
echo "No URLs checked."
return
fi
printf "%-6s %8s %9s   %s\n" "Code" "Count" "Percent" "Description"
echo "-------------------------------------------------------------"
sort "$codes_file" | uniq -c | sort -k2,2n | while read -r count code
do
printf "%-6s %8d %8s%%   %s\n" "$code" "$count" "$(LC_ALL=C awk -v c="$count" -v t="$total" 'BEGIN { printf "%.2f", c*100/t }')" "$(Status_Text $code)"
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
printf "%-6s %8d %8s%%\n" "UP" "$up" "$(LC_ALL=C awk -v c="$up" -v t="$total" 'BEGIN { printf "%.2f", c*100/t }')"
printf "%-6s %8d %8s%%\n" "DOWN" "$down" "$(LC_ALL=C awk -v c="$down" -v t="$total" 'BEGIN { printf "%.2f", c*100/t }')"
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

Convert_Log() {
# Converts results from the log file to CSV without checking the URLs again.
# Uses the "Status Of URL ... RUNNING" and "... is DOWN!!" lines, so older log files work too.
# A run is identified by its timestamp, default is the run of the last result in the log ($1=1: all runs).
local all_runs="$1" codes_file csv_file last_time
if [ ! -f "$SCRIPT_LOG" ] ; then
echo "$SCRIPT_LOG NOT FOUND!!"
exit 1
fi
# Descriptions for all status codes found in the log, used by awk below
codes_file=$(mktemp)
for code in $(grep -oE '(RUNNING \]([^ ]*)? |is DOWN!! )[0-9]{3}' "$SCRIPT_LOG" | grep -oE '[0-9]{3}$' | sort -u)
do
printf '%s\t%s\n' "$code" "$(Status_Text $code)" >> "$codes_file"
done
LC_ALL=C awk -v all_runs="$all_runs" -v sep="$CSV_SEP" -v codes_file="$codes_file" -v base="${SCRIPT_LOG%.*}" '
function parse(line,   p, q, r, n, parts, prefix) {
  # Remove color codes (real escape sequences and literal \E[..m)
  gsub(/\033\[[0-9;]*m/, "", line); gsub(/\\E\[[0-9;]*m/, "", line)
  if (substr(line, 1, 3) != "At ") return 0
  if ((p = index(line, ": Status Of URL ")) > 0) {
    r = substr(line, p + 16); q = index(r, " = [ RUNNING ] ")
    if (q == 0) return 0
    t = substr(line, 4, p - 4); url = substr(r, 1, q - 1); rest = substr(r, q + 15); status = "UP"
  } else if ((p = index(line, " URL ")) > 0 && (q = index(line, " is DOWN!! ")) > p) {
    t = substr(line, 4, p - 4); url = substr(line, p + 5, q - p - 5); rest = substr(line, q + 11); status = "DOWN"
  } else return 0
  n = split(rest, parts, " "); code = parts[1]; effective = ""
  # rest is "<code> <url> <effective url>" (older logs may only contain the code)
  prefix = code " " url " "
  if (substr(rest, 1, length(prefix)) == prefix) effective = substr(rest, length(prefix) + 1)
  else if (n >= 3) effective = parts[n]
  return 1
}
function csv(v) { gsub(/"/, "\"\"", v); return "\"" v "\"" }
function nice_time(v,   d) {
  # 13-10-2026_17.19.34 -> 2026-10-13 17:19:34
  if (v ~ /^[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]_[0-9][0-9]\.[0-9][0-9]\.[0-9][0-9]$/)
    return substr(v, 7, 4) "-" substr(v, 4, 2) "-" substr(v, 1, 2) " " substr(v, 12, 2) ":" substr(v, 15, 2) ":" substr(v, 18, 2)
  return v
}
BEGIN { while ((getline l < codes_file) > 0) { split(l, a, "\t"); desc[a[1]] = a[2] } }
# First pass: find the timestamp of the last result
FNR == NR { if (parse($0)) last = t; next }
FNR == 1 {
  if (last == "") { print "No results found in log file." > "/dev/stderr"; exit 1 }
  out = base "_" (all_runs == 1 ? "all" : last) ".csv"
  print "Time" sep "URL" sep "Status" sep "Code" sep "Description" sep "Effective URL" sep "Redirected" > out
}
# Second pass: write CSV
parse($0) && (all_runs == 1 || t == last) {
  print csv(nice_time(t)) sep csv(url) sep status sep code sep csv(desc[code]) sep csv(effective) sep (effective != "" && effective != url ? "yes" : "no") > out
  rows++
}
END { if (out != "") { close(out); print "Written " rows " rows to " out } }
' "$SCRIPT_LOG" "$SCRIPT_LOG"
local rc=$?
rm -f "$codes_file"
return $rc
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
echo "Usage: $0 [-s STREAMS] [-q] [-n]"
echo "       $0 -c [-a]"
echo "  -s STREAMS  Number of URLs checked in parallel (default: 10)"
echo "  -q          Quiet: show only progress bar and summary (results are still logged)"
echo "  -n          No progress bar"
echo "  -c          Convert the results of the last run in the log to CSV (no new run)"
echo "  -a          With -c: convert all runs in the log"
echo "  -h          Show this help"
}

# Make functions available for the parallel worker processes started by xargs
export -f Check_URL

QUIET=0
PROGRESS=1
CONVERT=0
ALL_RUNS=0
while getopts "s:qnhca" opt
do
case $opt in
s) STREAMS="$OPTARG" ;;
q) QUIET=1 ;;
n) PROGRESS=0 ;;
c) CONVERT=1 ;;
a) ALL_RUNS=1 ;;
h) Usage; exit 0 ;;
*) Usage; exit 1 ;;
esac
done

SetParam

# CSV export only: read the existing log file, do not check any URL
if [ "$CONVERT" = 1 ] ; then
Convert_Log "$ALL_RUNS"
exit $?
fi

case "$STREAMS" in
''|*[!0-9]*|0) echo "Invalid number of streams: '$STREAMS' (must be a positive integer)"; Usage; exit 1 ;;
esac
# Show the progress bar only if stderr is a terminal (not in cron jobs or when redirected)
[ -t 2 ] || PROGRESS=0
# Fit the progress bar into the terminal width (the text next to the bar needs about 55 characters)
TERM_COLS=$(stty size 2>/dev/null < /dev/tty | awk '{print $2}')
PROGRESS_WIDTH=$(( ${TERM_COLS:-95} - 55 ))
[ "$PROGRESS_WIDTH" -gt 40 ] && PROGRESS_WIDTH=40
[ "$PROGRESS_WIDTH" -lt 10 ] && PROGRESS_WIDTH=10
Main_Menu
Send_Log
