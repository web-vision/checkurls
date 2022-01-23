#!/bin/bash
#bash to check url status.
#set -x; # Enable this to enable debug mode.
#clear # Enable this to clear your screen after each run.

# What: Check URLs with their statuses and report it to an email address
# How to: Create a file named 'urllist.txt' and run this script.
#
# 2022-01-22 ChangeLog
# Removed 301 from SAFE Status Code and added follow Link and max-redirs to detect redirect loops

SetParam() {
export URLFILE="urllist.txt"
export TIME=`date +%d-%m-%Y_%H.%M.%S`

# Change Status codes here - eg. remove 301 redirects 
SAFE_STATUSCODES=( 200 201 202 203 204 205 206 207 208 226 401)
export STATUS_UP=`echo -e "\E[32m[ RUNNING ]\E[0m"`
export STATUS_DOWN=`echo -e "\E[33m[ DOWN ]\E[0m"`
export MAIL_TO="please-change-your@email-address-here.com"
export SCRIPT_LOG="Script_Monitor.log"
}

URL_Status() {

SetParam
# sed -i '/^$/d' $URLFILE; #To Parse the URLFILE for removal of blank rows
# cat $URLFILE | while read next # removed cat in favour of read line-by-line
while IFS= read -r next
do
# Added %{url} for requested URL and  %{url_effective for target URL, in case of broken rewrites, chanted http_code to response_code
STATUS_CODE=`curl -L --max-redirs 10 --output /dev/null --silent --head --write-out '%{response_code} %{url} %{url_effective}\n' "$next"`
# If you want to set a timeout then add --max-time 15, here 15 is 15seconds
case $STATUS_CODE in

100) echo "At $TIME: $next url status returned $STATUS_CODE : Continue" ;;
101) echo "At $TIME: $next url status returned $STATUS_CODE : Switching Protocols" ;;
102) echo "At $TIME: $next url status returned $STATUS_CODE : Processing (WebDAV) (RFC 2518) " ;;
103) echo "At $TIME: $next url status returned $STATUS_CODE : Checkpoint" ;;
122) echo "At $TIME: $next url status returned $STATUS_CODE : Request-URI too long" ;;
200) echo "At $TIME: $next url status returned $STATUS_CODE : OK" ;;
201) echo "At $TIME: $next url status returned $STATUS_CODE : Created" ;;
202) echo "At $TIME: $next url status returned $STATUS_CODE : Accepted" ;;
203) echo "At $TIME: $next url status returned $STATUS_CODE : Non-Authoritative Information" ;;
204) echo "At $TIME: $next url status returned $STATUS_CODE : No Content" ;;
205) echo "At $TIME: $next url status returned $STATUS_CODE : Reset Content" ;;
206) echo "At $TIME: $next url status returned $STATUS_CODE : Partial Content" ;;
207) echo "At $TIME: $next url status returned $STATUS_CODE : Multi-Status (WebDAV) (RFC 4918) " ;;
208) echo "At $TIME: $next url status returned $STATUS_CODE : Already Reported (WebDAV) (RFC 5842) " ;;
226) echo "At $TIME: $next url status returned $STATUS_CODE : IM Used (RFC 3229) " ;;
300) echo "At $TIME: $next url status returned $STATUS_CODE : Multiple Choices" ;;
301) echo "At $TIME: $next url status returned $STATUS_CODE : Moved Permanently" ;;
302) echo "At $TIME: $next url status returned $STATUS_CODE : Found" ;;
303) echo "At $TIME: $next url status returned $STATUS_CODE : See Other" ;;
304) echo "At $TIME: $next url status returned $STATUS_CODE : Not Modified" ;;
305) echo "At $TIME: $next url status returned $STATUS_CODE : Use Proxy" ;;
306) echo "At $TIME: $next url status returned $STATUS_CODE : Switch Proxy" ;;
307) echo "At $TIME: $next url status returned $STATUS_CODE : Temporary Redirect (since HTTP/1.1)" ;;
308) echo "At $TIME: $next url status returned $STATUS_CODE : Resume Incomplete" ;;
400) echo "At $TIME: $next url status returned $STATUS_CODE : Bad Request" ;;
401) echo "At $TIME: $next url status returned $STATUS_CODE : Unauthorized" ;;
402) echo "At $TIME: $next url status returned $STATUS_CODE : Payment Required" ;;
403) echo "At $TIME: $next url status returned $STATUS_CODE : Forbidden" ;;
404) echo "At $TIME: $next url status returned $STATUS_CODE : Not Found" ;;
405) echo "At $TIME: $next url status returned $STATUS_CODE : Method Not Allowed" ;;
406) echo "At $TIME: $next url status returned $STATUS_CODE : Not Acceptable" ;;
407) echo "At $TIME: $next url status returned $STATUS_CODE : Proxy Authentication Required" ;;
408) echo "At $TIME: $next url status returned $STATUS_CODE : Request Timeout" ;;
409) echo "At $TIME: $next url status returned $STATUS_CODE : Conflict" ;;
410) echo "At $TIME: $next url status returned $STATUS_CODE : Gone" ;;
411) echo "At $TIME: $next url status returned $STATUS_CODE : Length Required" ;;
412) echo "At $TIME: $next url status returned $STATUS_CODE : Precondition Failed" ;;
413) echo "At $TIME: $next url status returned $STATUS_CODE : Request Entity Too Large" ;;
414) echo "At $TIME: $next url status returned $STATUS_CODE : Request-URI Too Long" ;;
415) echo "At $TIME: $next url status returned $STATUS_CODE : Unsupported Media Type" ;;
416) echo "At $TIME: $next url status returned $STATUS_CODE : Requested Range Not Satisfiable" ;;
417) echo "At $TIME: $next url status returned $STATUS_CODE : Expectation Failed" ;;
500) echo "At $TIME: $next url status returned $STATUS_CODE : Internal Server Error" ;;
501) echo "At $TIME: $next url status returned $STATUS_CODE : Not Implemented" ;;
502) echo "At $TIME: $next url status returned $STATUS_CODE : Bad Gateway" ;;
503) echo "At $TIME: $next url status returned $STATUS_CODE : Service Unavailable" ;;
504) echo "At $TIME: $next url status returned $STATUS_CODE : Gateway Timeout" ;;
505) echo "At $TIME: $next url status returned $STATUS_CODE : HTTP Version Not Supported" ;;
esac

URL_SafeStatus $STATUS_CODE

done < "$URLFILE";

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
SetParam
Main_Menu | tee -a $SCRIPT_LOG
Send_Log
