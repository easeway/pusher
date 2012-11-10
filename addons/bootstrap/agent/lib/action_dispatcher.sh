_ACTIONS_REPORT="$PUSHER_ENV_BASE/action_report"
_ACTIONS_REVISION="$PUSHER_ENV_BASE/action_revision"
_ACTIONS_LOG="$PUSHER_ENV_BASE/action_log"
_ACTIONS_CMD="$PUSHER_ENV_BASE/action_cmd"

_ACTIONS_COMMANDS=""

_actions_clean_result() {
    safe_rm_all "$_ACTIONS_REPORT"
    safe_rm_all "$_ACTIONS_LOG"
}

_actions_report_result() {
    local rev=$1 ret=$2

    [ $ret -eq 0 ] && echo -n "$rev" >"$_ACTIONS_REVISION"

    echo -n "$rev:$ret" >"$_ACTIONS_REPORT"

    local done=0
    for ((i=0; i<3; i=i+1)); do
        request POST "result/$rev/$ret" -H "Content-Type: text/plain" --data "@$_ACTIONS_LOG" \
            && done=1 && break
    done

    [ $done -eq 1 ] && _actions_clean_result
    [ $done -ne 1 ] && return 1
    return 0
}

_actions_recover_report() {
    if [ -f "$_ACTIONS_REPORT" ]; then
        local rev=$(extract_val '^([[:digit:]]+):.+$' "$_ACTIONS_REPORT")
        local ret=$(extract_val '^[[:digit:]]+:([[:digit:]]+)$' "$_ACTIONS_REPORT")
        if [ -n "$rev" ] && [ -n "$ret" ]; then
            _actions_report_result $rev $ret
            return $?
        else
            _actions_clean_result
        fi
    fi
    return 0
}

_actions_internal_cmd() {
    local cmd=$1
    shift
    for reg_cmd in $_ACTIONS_COMMANDS ; do
        if [ "$cmd" == "$reg_cmd" ]; then
            pusher_action_$cmd $@
            return $?
        fi
    done

    echo "Unknown command: $cmd $*"
    return 1
}

_actions_invoke_addon() {
    local entry="$PUSHER_HOME/$_ACTIONS_CMD_ADDON/start"
    [ -x "$entry" ] || entry="$PUSHER_BUILTIN_DIR/$_ACTIONS_CMD_ADDON/start"
    if [ -x "$entry" ]; then
        "$entry" $_ACTIONS_CMD_LINE <"$_ACTIONS_CMD" 2>&1
        return $?
    else
        echo "Addon unavailable: $_ACTIONS_CMD_ADDON $_ACTIONS_CMD_LINE"
        return 1
    fi
}

_actions_command_complete() {
    local ret reported
    if [ -z "$_ACTIONS_CMD_ADDON" ]; then
        _actions_internal_cmd $_ACTIONS_CMD_LINE >"$_ACTIONS_LOG"
    else
        _actions_invoke_addon >"$_ACTIONS_LOG"
    fi
    ret=$?

    safe_rm_all "$_ACTIONS_CMD"

    _actions_report_result $_ACTIONS_CMD_REVISION $ret
    reported=$?

    unset _ACTIONS_CMD_REVISION
    unset _ACTIONS_CMD_ADDON
    unset _ACTIONS_CMD_LINE

    [ $ret -eq 0 ] && [ $reported -eq 0 ] || return 1
    return 0
}

# Parsing the sync payload
# The payload looks like
# REVISION:ADDON_NAME:COMMAND_LINE
_actions_parse() {
    local state="ready" rev addon cmdline

    while read; do
        case $state in
            ready)
                rev=$(echo "$REPLY" | sed -r 's/^([[:digit:]]+):.+$/\1/')
                addon=$(echo "$REPLY" | sed -r 's/^[[:digit:]]+:([[:alnum:]_-]*):.*$/\1/')
                cmdline=$(echo "$REPLY" | sed -r 's/^[[:digit:]]+:[^:]*:(.*)$/\1/')
                if [ -n "$rev" ]; then
                    _ACTIONS_CMD_REVISION="$rev"
                    _ACTIONS_CMD_ADDON="$addon"
                    _ACTIONS_CMD_LINE="$cmdline"
                    safe_rm_all "$_ACTIONS_LOG"
                    new_file "$_ACTIONS_CMD"
                    state="data"
                fi
                ;;
            data)
                local token=$(echo "$REPLY" | sed -r 's/^([[:digit:]]+)\.$/\1/')
                if [ "$token" == "$rev" ]; then
                    _actions_command_complete || return 1
                    state="ready"
                else
                    echo "$REPLY" >> "$_ACTIONS_CMD"
                fi
                ;;
        esac
    done
}

actions_register() {
    _ACTIONS_COMMANDS="$_ACTIONS_COMMANDS $*"
}

actions_process() {
    _actions_recover_report || return 1
    request GET "sync" | _actions_parse
}
