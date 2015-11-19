#!/usr/bin/bash

appname=streamwall
FILE="./wallpaper.png"
NEW_FILE="./wallpaper_new.png"
OLD_FILE="./wallpaper_old.png"

show_help () {
    cat << EOF
Usage: $appname [OPTIONS]

Set images from livestreams as wallpaper at a given interval.
By default it uses the HDEV-stream from the International Space Station
(ISS)
You can use any other livestream that can be handled by 'livestreamer'.
See man livestreamer for more information.

Optional arguments:
  -h              Show this help message and exit
  -s <url>        Stream url (defaults to
                    'https://www.ustream.tv/channel/iss-hdev-payload')
  -q <quality>    Quality (defaults to 'best'. See 'man livestreamer'
                    for more information)
  -o              One-shot
  -b              Ignore blank images
  -n              Ignore error-images from ISS
  -t              Put a timestamp on the wallpaper
  -f <command>    Command to set the wallpaper (defaults to
                    'feh --bg-scale {%FILE}')
  -w              Seconds to wait before getting the next image
                    (defaults to 120)
  -d              Print debug-messages

You can find the actual and the previous wallpaper in $HOME/.streamwall
EOF
}

parse_args () {
    # A POSIX variable
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # Initialize our own variables:
    stream_url="https://www.ustream.tv/channel/iss-hdev-payload"
    quality="best"
    one_shot=false
    blank_ignore=false
    no_error=false
    do_timestamp=false
    feh_cmd="feh --bg-scale $FILE"
    wait_for=120
    debug=false

    while getopts "h?s:q:obntf:w:d" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        s)  stream_url=$OPTARG
            ;;
        q)  quality=$OPTARG
            ;;
        o)  one_shot=true
            ;;
        b)  blank_ignore=true
            ;;
        n)  no_error=true
            ;;
        t)  do_timestamp=true
            ;;
        f)  # replace '{%FILE}' with $FILE
            feh_cmd="${OPTARG/\{\%FILE\}/$FILE}"
            ;;
        w)  if [[ $OPTARG =~ ^[0-9]+$ ]]; then
                wait_for=$OPTARG
            else
                echo "ERROR: -w needs to be an integer"
                show_help
                exit 1
            fi
            ;;
        d)  debug=true
            ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift
}

dep_check () {
    error=false
    if ! which livestreamer >> /dev/null 2>&1; then
        error=true
        echo "ERROR: $appname needs 'livestreamer' to be installed!"
    fi

    if ! which ffmpeg >> /dev/null 2>&1; then
        error=true
        echo "ERROR: $appname needs 'ffmpeg' to be installed!"
    fi

    if ! which convert >> /dev/null 2>&1; then
        error=true
        echo "ERROR: $appname needs 'imagemagick' to be installed!"
    fi

    cmd_list=($feh_cmd)
    if [ "${cmd_list[0]}" == "feh" ]; then
        if ! which feh >> /dev/null 2>&1; then
            error=true
            echo "ERROR: $appname needs 'feh' to be installed!"
        fi
    fi

    if $error; then
        echo "Abort"
        exit 1
    fi
}

timestamp () {
    convert "$FILE" -gravity SouthEast -pointsize 14 -fill white -undercolor '#00000080' -annotate +1+3  "$(date)" "$FILE"
}

cleanup () {
    if [ -f "$NEW_FILE" ]; then
        rm "$NEW_FILE"
    fi
}

interval () {
    cleanup
    if $one_shot; then
        exit 0
    fi
    END=$(date "+%s.%3N")
    DIFF=$(echo "$END - $START" | bc)
    # let's assume the next capture will take the same amount of time
    WAIT=$(echo "$wait_for - $DIFF" | bc)
    if (( $(bc <<< "$WAIT < 2") )); then
        WAIT=2
    fi
    echo "Sleep for $WAIT seconds"
    sleep $WAIT
}

find_scriptdir () {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    realpath "$DIR"
}

compare_against () {
    # $1 = file to use for comparsion
    # $2 = threshold
    if [ -f "$1" ]; then
        diff=$(compare -metric PSNR $NEW_FILE "$1" NULL: 2>&1)
        if [ $? == 2 ]; then
            echo "WARNING: Failed to compare image against $1! Maybe the image widths or heights differ."
            return
        fi
        if $debug; then echo "DEBUG: ${1##*/} diff: $diff"; fi
        if (( $(bc <<< "$diff > $2") )) || [ "$diff" == "inf" ]; then
            echo "New image matched ${1##*/}"
            return 1
        fi
    else
        echo "Couldn't find the file $1"
    fi
}


parse_args "$@"

dep_check

if [ -f "$HOME"/.$appname ]; then
    echo "ERROR: There is a file '$HOME/.$appname' that conflicts with $appname."
    exit 1
fi

if ! [ -d "$HOME"/.$appname ]; then
    mkdir "$HOME"/.$appname
fi

scriptdir=$(find_scriptdir)

cd "$HOME"/.$appname || exit

# first set wallpaper from last boot, if available, in case we run after a reboot
if [ -f "$FILE" ]; then
    $feh_cmd
    if [ $? == 0 ]; then
        echo "previous wallpaper set"
    else
        echo "ERROR: the command to set the wallpaper seems to have failed"
        exit 1
    fi
fi

while true; do
    START=$(date "+%s.%3N")
    if ! livestreamer --player "ffmpeg -i" --player-args "{filename} -y -vframes 1 $NEW_FILE" "$stream_url" "$quality"; then
        echo "failure"
        interval
        continue
    fi

    if ! [ -f $NEW_FILE ]; then
        echo "failure"
        interval
        continue
    fi

    if $no_error; then
        if ! compare_against "$scriptdir/images/iss_error.png" 20; then
            interval
            continue
        fi
    fi

    if $blank_ignore; then
        if ! compare_against "$scriptdir/images/black.png" 30; then
            interval
            continue
        fi
        if ! compare_against "$scriptdir/images/grey.png" 50; then
            interval
            continue
        fi
    fi

    # Use custom filter-images
    if [ -d "$HOME"/.$appname/filters ]; then
        filter_active=false
        for data in "$HOME"/.$appname/filters/*; do
            if file -i "$data" | grep -q "image/"; then
                threshold_raw=($(echo "$data" | egrep -o [0-9]+))
                if [ ${#threshold_raw[@]} -eq 0 ]; then
                    threshold=20
                else
                    threshold="${threshold_raw[-1]}"
                fi
                if [ "$threshold" -gt 100 ]; then
                    threshold=100
                fi
                if ! compare_against "$data" "$threshold"; then
                    filter_active=true
                    break
                fi
            fi
        done
        if $filter_active; then
            interval
            continue
        fi
    fi

    if [ -f "$FILE" ]; then
        mv "$FILE" "$OLD_FILE"
    fi
    mv "$NEW_FILE" "$FILE"
    if $do_timestamp; then
        timestamp
    fi

    $feh_cmd
    if [ $? == 0 ]; then
        echo "new wallpaper set"
    else
        echo "ERROR: the command to set the wallpaper seems to have failed"
        exit 1
    fi
    interval
done
