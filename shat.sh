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

# werether or not a pipe is being drained
pipearg=""

# usage: cat "file" | hi_li [file name]
# highlighter wrapper
# receives file from std in, can get file name as arg
hi_li () {
    if [ -z "$pipearg" ]; then
        case "$HIGHLIGHTER" in
            *highlight*)
                # we may be reading a symlink, the symlink may not have an
                # extension but the real file it points to could so we try
                # to get that file name
                file=$(readlink -f "$1")
                file="${file##*/}"
                ext="${file##*\.}"
                # only do syntax by name if the file name got a real extension
                if [ "$ext" != "$file" ]; then
                    ${HIGHLIGHTER} --syntax-by-name "$file"
                else
                    ${HIGHLIGHTER}
                fi
            ;;
            *)
                ${HIGHLIGHTER}
            ;;
        esac
    else
        ${HIGHLIGHTER}
    fi
}

# the columns on the left of the printable area
margin=9

# if ran as a preview for fzf use the fzf previe columns
[ -z "$FZF_PREVIEW_COLUMNS" ] || SHBAT_COLS="$FZF_PREVIEW_COLUMNS"
if [ -z "$SHBAT_COLS" ]; then
    clnms=$(( $(tput cols) - margin ))
else
    clnms=$(( SHBAT_COLS - margin ))
fi

# usage: is_num "value"
is_num() {
    printf %d "$1" >/dev/null 2>&1
}

# usage: trim_iden "value"
#     will trim input to 6 chars
trim_iden() {
    printf '%.6s\n' "$1"
}

show_usage () {
    printf 'usage: %s [OPTION] [FILE]\n' "${myname}"
}

show_help () {
    printf '%s\n'   "${myname}: bat imitation with minimal dependencies"
    show_usage
    printf '\n%s\n'   "Options:"
    printf '%s\n'     "-I S"
    printf '\t%s\n'   "where 'S' is the identifier string."
    printf '%s\n'     "-N S"
    printf '\t%s\n'   "where 'S' is the file name string."
    printf '%s\n'     "-c N"
    printf '\t%s\n'   "where 'N' is the column width of the display area."
    printf '\t%s\n'   "if not provided tput cols will be used to determine the display area"
    printf '\t%s\n'   "when called from fzf the \$FZF_PREVIEW_COLUMNS variable is used instead."
    printf '%s\n'     "-H"
    printf '\t%s\n'   "do not print header"
    printf '%s\n'     "-B"
    printf '\t%s\n'   "do not print top and bottom borders nor header"
    printf '%s\n'     "-h"
    printf '\t%s\n'   "show this message"
    printf '\n%s\n'   "Hihghlighting:"
    printf '\t%s%s\n' "by default the script will try to use either 'highlight'" \
                      " or 'source-highlight'"
    printf '\t%s\n'   "to use a different highlighter you have to set or export the \$HIGHLIGHTER"
    printf '\t%s%s\n' "variable with your code highlighter of choice and the necessary flags" \
                      " so that it"
    printf '\t%s\n'   "will output in ANSI escape sequences."
}

ident=""
name=""
noheader=""
noborder=""
while getopts "c:I:N:HBh" opt; do case "${opt}" in
    c)
        if is_num "$OPTARG"; then
            clnms=$(( OPTARG - margin ))
        else
            printf '%s: argument for -%s "%s" is not a number\n' "${myname}" "$opt" "$OPTARG" >&2
            exit 1
        fi
    ;;
    I) ident=$(trim_iden "$OPTARG") ;;
    N) name="$OPTARG" ;;
    H) noheader=1 ;;
    B) noborder=1 ;;
    h) show_help ; exit 0 ;;
    *)
        printf '%s: invalid option %s\n' "${myname}" "$opt" >&2
        show_usage
        exit 1
    ;;
esac done
shift $(( OPTIND -1 ))

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
    if [ -z "$noheader" ] && [ -z "$noborder" ]; then
        printseparators "top"
        printf '\033[30;1m%6s %s\033[0m \033[32;1m%s\033[0m \n' "$iD" "│" "$*"
        printseparators "mid"
    elif [ -z "$noborder" ]; then
        printseparators "top"
    fi
    num=1
    while IFS= read -r REPLY; do
        printf '\033[30;1m%6d %s\033[0m %s \n' "$num" "│" "$REPLY"; num=$((num+1))
    done
    if [ -z "$noborder" ]; then
        printseparators "bot"
    fi
}

tmpfile="${TMPDIR:-/tmp}/${myname}_pipe_$$"
trap 'rm -f -- $tmpfile' EXIT

if [ "$#" -eq 0 ]; then
    if [ -t 0 ]; then
        echo "${myname}: No FILE arguments provided" >&2; exit 1
    else
        # Consume stdin and put it in the temporal file
        /bin/cat > "$tmpfile"
        pipearg=1
    fi
fi

for arg in "$@"; do
    # if it's a pipe then drain it to $tmpfile
    [ -p "$arg" ] && { pipearg=1; /bin/cat "$arg" > "$tmpfile"; };
done

if [ -z "$pipearg" ]; then
    [ -z "$ident" ] && ident="File"
    if [ "$#" -gt 1 ]; then
        /bin/cat "$@" | fold -s -w "$clnms" | prettyprintcmd "$ident" "$@"
    else
        case "$1" in
            *.gz|*.zst|*.zip|*.tar|*.doc|*.deb|*.jar|*.7z)
                lesspipe "$1" | fold -s -w "$clnms" | prettyprintcmd "$ident" "$@"
            ;;
            *)
                if [ -d "$1" ]; then
                    if [ -z "$FZF_PREVIEW_LINES" ]; then
                        tree "$1" | fold -s -w "$clnms" | prettyprintcmd "$ident" "$@"
                    else
                        rows="$FZF_PREVIEW_LINES"
                        rows=$(( rows - 4))
                        tree "$1" | head -n "$rows" | fold -s -w "$clnms" | \
                            prettyprintcmd "$ident" "$@"
                    fi
                else
                    fold -s -w "$clnms" "$1" | hi_li "$@" | prettyprintcmd "$ident" "$@"
                fi
            ;;
        esac
    fi
else
    [ -z "$ident" ] && ident="Pipe"
    [ -z "$name" ] && name="${myname}-pipe $$"
    fold -s -w "$clnms" "$tmpfile" | hi_li | prettyprintcmd "$ident" "$name"
fi
