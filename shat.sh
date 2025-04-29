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

# the columns on the left of the printable area
margin=9

# if ran as a preview for fzf use the fzf previe columns
[ -z "$FZF_PREVIEW_COLUMNS" ] || SHBAT_COLS="$FZF_PREVIEW_COLUMNS"
if [ -z "$SHBAT_COLS" ]; then
    clnms=$(( $(tput cols) - margin ))
else
    clnms=$(( SHBAT_COLS - margin ))
fi

ident=""
name=""

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
    iD="$1"
    shift 1
    printseparators "top"
    printf '\033[30;1m%6s %s\033[0m \033[32;1m%s\033[0m \n' "$iD" "│" "$*"
    printseparators "mid"
    num=1
    while IFS= read -r REPLY; do
        printf '\033[30;1m%6d %s\033[0m %s \n' "$num" "│" "$REPLY"; num=$((num+1))
    done
    printseparators "bot"
}

tmpfile="${TMPDIR:-/tmp}/${myname}_pipe_$$"
trap 'rm -f -- $tmpfile' EXIT

if [ "$#" -eq 0 ]; then
    if [ -t 0 ]; then
        echo "${myname}: No FILE arguments provided" >&2; exit 1
    else
        # Consume stdin and put it in the temporal file
        cat > "$tmpfile"
        pipearg=1
    fi
fi

for arg in "$@"; do
    # if it's a pipe then drain it to $tmpfile
    [ -p "$arg" ] && { pipearg=1; cat "$arg" > "$tmpfile"; };
done

if [ -z "$pipearg" ]; then
    [ -z "$ident" ] && ident="File"
    if [ "$#" -gt 1 ]; then
        /bin/cat "$@" | prettyprintcmd "$ident" "$@"
    else
        $HIGHLIGHTER "$1" | prettyprintcmd "$ident" "$@"
    fi
else
    [ -z "$ident" ] && ident="Pipe"
    [ -z "$name" ] && name="${myname}-pipe $$"
    $HIGHLIGHTER "$tmpfile" | prettyprintcmd "$ident" "$name"
fi
