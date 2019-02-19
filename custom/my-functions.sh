#!/bin/bash
#
#  V1.0   20/08/2008  VK8SJ   File created to ease RSI (repeditive shell input)
#
#
##############################################################################
#
# This is a shell snippet containing some common functions to do menial tasks,
# Instead of duplicating effort in many places.  Taken from IRLP file
# common-functions.sh and added, twisted, etc... This file can be sourced
# as well as common-functions.sh (no duplicate function declaration error)
#
##############################################################################
#
# Make sure we are user repeater!!!
   if [ "`/usr/bin/whoami`" != "repeater" ] ; then
     echo "This program must be run as user REPEATER!"
     exit 1
   fi
# Make sure we have sourced the environment file
   if [ "$RUN_ENV" != "TRUE" ] ; then
      . /home/irlp/custom/environment
   fi
#############################################################################
#
# Variable Definitions..
   ESC="\033"

#############################################################################
############################# Functions #####################################
#############################################################################
#
### Logging ..
#
# This function logs Date etc and running script name, then message..
#
function writelog2 () {
  MESSAGE="`date '+%b %d %Y %T %z'` ${0##*/}: "$@
  if [ -n "$LOGFILE" ]; then
    echo $MESSAGE >> $LOGFILE
  fi
}

# This function logs Date etc then message..
#   (omits running script name)
#
function writelog () {
  MESSAGE="`date '+%b %d %Y %T %z'` "$@
  if [ -n "$LOGFILE" ]; then
    echo $MESSAGE >> $LOGFILE
  fi
}

### Unlog...
# Unlog (?) the last writelog...
#
#
function unlog () {
   LogLines=`wc -l $LOGFILE | awk '{print($1)}'`
   LogLines=`expr $LogLines - 1`
   head -n$LogLines $LOGFILE > $LOGFILE.rehash
   rm -f $LOGFILE
   mv $LOGFILE.rehash $LOGFILE
   writelog2 "Log entry removed."    # So There!! pfthththth!
}

### Key...
# Key the PTT. If the PTT manager program is running then use it;
# otherwise, just mash it
#
function my_key () {
   if ps -C ptt -o pid= >&/dev/null
   then
      echo "+" > $LOCAL/ptt_fifo
   else
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/coscheck
      $BIN/forcekey
   fi
}

### Unkey
# Unkey the PTT. If the PTT manager program is running, then use it;
# otherwise, just bury it
#
function my_unkey () {
   if ps -C ptt -o pid= >&/dev/null
   then
      echo "-" > $LOCAL/ptt_fifo
   else
      $BIN/forceunkey
   fi
}

### Restart CWID
# Restarts the CWID sequence when it has been stopped
#
#
function restartcwid () {
   rm -f /home/irlp/local/cwtimer    # remove lockout flag file
   /home/irlp/custom/cwtimer_mon     # force restart the loop
}
 
### Send Tone
# Key the PTT, wait for a while (specified amount of time below),
# play the confirmation beep-beep wav file, then unkey the PTT
#
function sendtone () {
   my_key
   usleep 500000
   #$BIN/play $AUDIO/custom/sound-confirm.wav     # contains 'beep beep' or whatever
   #usleep 500000
   my_unkey
}

### Send Error
# Key PTT, wait and then play the 'error' sound file
# If 'notx' on command line, error plays on local monitor
# speaker only, no ptt issued thus no tx!
#
function senderror () {
  if [ "$1" != "notx" ]; then
    my_key
    usleep 500000
    $BIN/play $AUDIO/custom/sound-error.wav  # whatever you want for errors
    $BIN/play $AUDIO/error.wav               # add std error message
    usleep 500000
    my_unkey
   else
    $BIN/play $AUDIO/custom/sound-error.wav
    $BIN/play $AUDIO/error.wav
  fi
}

### Send Completed
# Key PTT, wait then send out command completed sound file
#
#
function sendcomplete () {
  my_key
  usleep 500000
  $BIN/play $AUDIO/custom/sound-complete.wav
  usleep 500000
  my_unkey
}

### Send Voice Response
# Key PTT, wait then speak from requested text
# or SSML file. Set mode with 2nd parameter ($2)
# - defaults to text
#  (use 'quote' if no file involved)
#
function sendvoice () {
  my_key
  usleep 500000
  case $TTSengine in
  swift)      case $2 in
                text)   /opt/swift/bin/swift -m text -f $1 ;;
                ssml)   /opt/swift/bin/swift -f $1 ;;
                quote)  /opt/swift/bin/swift $1 ;;
		google) /home/irlp/custom/speak $1 ;;
                *)      /opt/swift/bin/swift -m text -f $1 ;;
              esac ;;
  *)          /usr/bin/festival --tts $1 ;;
  esac 
  usleep 250000
  my_unkey
}

### PlayMP3
# Key the PTT, play MP3 file passed in command line, then unkey
#  Filename should be specified without the extension.  If second
#  parameter is 'txon' the routine will not shut down tx on completion
#
function playmp3 () {
  my_key
  usleep 500000
  echo "Playing $1.mp3"
  /usr/bin/mpg123 $1.mp3 > /dev/null 2>&1
  usleep 200000
  if [ "$2" != "txon" ] ; then
    my_unkey
  fi
}

### PlayWAV
# Key the PTT, play WAV file passed in command line, then unkey
#  Filename should be specified with the extension     
#
function playwav () {
  my_key                  
  usleep 500000
  echo "Playing $1"
  $BIN/play $1 > /dev/null 2>&1
  usleep 200000
  if [ "$2" != "txon" ] ; then
    my_unkey
  fi
}

### CRSR and TXTCol
# 'crsr ln col'   - Cursor position (x,y)
# 'txtcol fg bg att'  - Colour of text, foreground, background, attribute
# these commands control the displays cursor via ANSI escape codes. The 
# codes control cursor position and colour, as well as screen colour.
# Errors handled by 'dummyspit 5'
#  It goes something like this....
function crsr () {
  LN=$1
  COL=$2
  if [ -z $LN ] || [ -z $COL ]; then dummyspit 5; fi
  echo -en $ESC"["$LN";"$COL"H"
}

function txtcol () {
  FG=$1
  BG=$2
  ATT=$3
#  Forground colour minimum requirement
  if [ -z $FG ]; then dummyspit 5; fi
  case $FG in
    def)      echo -en $ESC"[0m" ;;  # Default screen attributes
    red)      echo -en $ESC"[31m" ;;
    grn)      echo -en $ESC"[32m" ;;
    yel)      echo -en $ESC"[33m" ;;
    blu)      echo -en $ESC"[34m" ;;
    mag)      echo -en $ESC"[35m" ;;
    cyn)      echo -en $ESC"[36m" ;;
    wht)      echo -en $ESC"[37m" ;;
    *)        echo "OH Nooooo..."
              dummyspit 5 ;;
  esac

  case $BG in
    blk)      echo -en $ESC"[40m" ;;
    red)      echo -en $ESC"[41m" ;;
    grn)      echo -en $ESC"[42m" ;;
    yel)      echo -en $ESC"[43m" ;;
    blu)      echo -en $ESC"[44m" ;;
    mag)      echo -en $ESC"[45m" ;;
    cyn)      echo -en $ESC"[46m" ;;
    wht)      echo -en $ESC"[47m" ;;
  esac

  case $ATT in
    blink)    echo -en $ESC"[5m" ;;
    bold)     echo -en $ESC"[1m" ;;
    italic)   echo -en $ESC"[3m" ;;
  esac
 
}

### Error Handler..
# This function is called with the error number in command line
# and logs, cleans up etc from errors - extend by adding to the case
# statement the error number you require and actions to perform.
#
#  ** Always Under Construction! **
#
function dummyspit () {
  SPIT=$1               # main error category
  WHYSPIT=$2            # More detail if needed
  txtcol red
  echo "Oh CRAP! - error #"$SPIT"."$WHYSPIT
  echo "Fixing up mess now.."
  txtcol def
  senderror
  case $SPIT in
# 0- makes no sense, not an error...
  0)       echo "No mess Charlie... Why you wake me up?";;

# 1- From getNEWS files
  1)       rm $NEWS/index* > /dev/null 2>&1
           rm $NEWS/robot* > /dev/null 2>&1
	   writelog "TWIAR Download FAILED!" ;;

# 2- Vacant at the moment!

# 3- From ncftpget in getQ news
  3)       txtcol red blk blink
           echo "Qnews download FAILED!"
           txtcol def
           echo
           writelog "Qnews file download Failure." ;;

# 4- From ncftpget in WIA news
  4)       txtcol red blk blink
           echo "WIA News file download FAILED!"
           txtcol def
           echo
           writelog "WIA news file download Failure." ;;

# 5- From cursor controls
  5)       txtcol red blk blink
           echo "Illegal Function Parameter"
           txtcol def
           echo ;;

# 6- From playremotedata script
  6)       txtcol red blk blink
           case $WHYSPIT in
             1)  echo "Status page file download error"
                 writelog2 "Status page download error"
                 rm -f $LOCAL/active ;;
             2)  echo "**ERROR** Wrong DTMF information supplied"
                 writelog2 "DTMF information missing or invalid" ;;
             3)  echo "Node is either active or disabled. Request denied!"
                 writelog2 "Node Active or Disabled - denied." ;;
             4)  echo "Called with incorrect prefix... "$CALL_PREFIX". Exiting."
                 writelog2 "Prefix incorrect - "$CALL_PREFIX
                 rm -f $LOCAL/active ;;
             5)  echo "Got formatting error.. Page download failed.."
                 writelog2 "Status page decode error"
                 rm -f $LOCAL/active ;;
           esac
           txtcol def
           echo ;;

# 7- from BOM (Met Bureau) script
  7)       txtcol red blk blink
           case $WHYSPIT in
             1)  echo "File download error"
                 writelog2 "File download error"
                 rm -f $Workdir/river_dump ;;
             2)  echo "**ERROR** Wrong DTMF information supplied"
                 writelog2 "DTMF information missing or invalid" ;;
             3)  echo "Node is either active or disabled. Request denied!"
                 writelog2 "Node Active or Disabled - denied." ;;
             4)  echo "Incorrect function received."
                 writelog2 "Incorrect function request." ;;
           esac
           txtcol def
           echo ;;

# 8- from lastline script
  8)       txtcol red blk blink
           case $WHYSPIT in
             1)  echo "**ERROR** No line count specified."
                 writelog2 "DTMF information missing or invalid" ;;
             2)  echo "Node is either active or disabled. Request denied!"
                 writelog2 "Node Active or Disabled - denied." ;;
           esac
           txtcol def
           echo ;;

# Last ditch catch-all is here..
  *)       txtcol red blk blink
           echo "WHAT!! even stuffed up the error!"
           echo "    NO ERROR NUMBER REPORTED"
           txtcol def
           echo ;;
  esac
exit 100   # terminate script completely, with exitcode 100 'error'

}

### End Functions
#########################################################################
