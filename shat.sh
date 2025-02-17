#!/bin/sh

myname=${0##*/}

# usage: check_cmd command
#     returns the command if it exists
check_cmd(){
    [ "$(command -v "$1" 2>/dev/null)" ] && printf '%s\n' "$1"
}

no_hl_err="no HIGHLIGHTER found, install a highlighter program or set the env var HIGHLIGHTER"
[ -z "$HIGHLIGHTER" ] && HIGHLIGHTER="$(check_cmd highlight)"
[ -z "$HIGHLIGHTER" ] && HIGHLIGHTER="$(check_cmd source-highlight)"
[ -z "$HIGHLIGHTER" ] && { printf '%s: %s\n' "$myname" "$no_hl_err" >&2 ; exit 1; }
case "$HIGHLIGHTER" in
    *source-highlight) HIGHLIGHTER="${HIGHLIGHTER} -f esc -i" ;;
    *highlight) HIGHLIGHTER="${HIGHLIGHTER} -O ansi --force" ;;
esac

if [ -z "$SHBAT_COLS" ]; then
   clnms="$(tput cols)"
else
   clnms="$SHBAT_COLS"
fi
clnms=$((clnms-8))
sepLeft="───────"
count=1
while [ "$count" -le "$clnms" ]; do sepRight="${sepRight}─"; count=$((count+1)); done
printseparators() {
    case "$1" in
        top) sepChar="┬" ;;
        mid) sepChar="┼" ;;
        bot) sepChar="┴" ;;
    esac
    printf '\033[30;1m%s%s%s\033[0m\n' "$sepLeft" "$sepChar" "$sepRight"
}

prettyprintcmd() {
    printseparators "top"
    printf '\033[30;1m%6s %s\033[0m \033[32;1m%s\033[0m \n' "File:" "│" "$*"
    printseparators "mid"
    num=1
    while IFS= read -r REPLY; do
        printf '\033[30;1m%6d %s\033[0m %s \n' "$num" "│" "$REPLY"; num=$((num+1))
    done
    printseparators "bot"
}

if [ "$#" -gt 1 ]; then
    /bin/cat "$@" | prettyprintcmd "$@"
else
    $HIGHLIGHTER "$1" | prettyprintcmd "$@"
fi
