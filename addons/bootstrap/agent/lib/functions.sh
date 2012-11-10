request() {
    local method=$1 path=$2 accept_type="$ACCEPTS"
    shift
    shift
    [ -z "$accept_type" ] && accept_type="text/plain"
    curl \
        -H "Accept: $accept_type" \
        -H "X-Pusher-Client-Id: $PUSHER_CLIENT_ID" \
        -X $method $@ \
        "$PUSHER_SERVER/$path"
}

extract_val() {
    local regex="$1" result=""
    if [ -n "$2" ]; then
        [ -f "$2" ] && result=$(grep -E "$regex" "$2" | sed -r "s/$regex/\\1/")
    else
        result=$(grep -E "$regex" | sed -r "s/$regex/\\1/")
    fi
    [ -z "$result" ] && [ -n "$DEFAULT_VAL" ] && result="$DEFAULT_VAL"
    echo -n "$result"
}

safe_rm() {
    local opts="" files=""
    for fn in "$@"; do
        if [ "${fn:0:1}" == "-" ]; then
            opts="$opts $fn"
        else
            local dirname=$(dirname "$fn" | grep -E '^.+/pusher')
            if [ -n "$dirname" ]; then
                [ -z "$files" ] && files="$fn" || files="$files $fn"
            else
                log error "Unsafe rm: $fn"
            fi
        fi
    done
    [ -n "$files" ] && rm $opts $files
}

safe_rm_all() {
    safe_rm -fr "$@"
}

new_dir() {
    safe_rm -fr "$@"
    mkdir -p "$@"
}

new_file() {
    local path=$(dirname "$1")
    safe_rm_all "$1"
    mkdir -p "$path"
    touch "$1"
}
