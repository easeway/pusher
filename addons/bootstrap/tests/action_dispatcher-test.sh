source "$TESTS_SCRIPT_DIR/test_env.sh"

source "$SRC_BASE/agent/lib/functions.sh"

# Fake environment
PUSHER_BUILTIN_DIR="$PUSHER_LIB_BASE/addons"

# Fake functions
request() {
    REQUEST_COUNT=$((REQUEST_COUNT+1))
    REQUEST_METHOD=$1
    REQUEST_URL="$2"

    case $REQUEST_METHOD in
        GET)
            echo "$RESPONSE"
            ;;
        POST)
            ${POST_ACTION}
            ;;
    esac
}

source "$SRC_BASE/agent/lib/action_dispatcher.sh"

on_post_save_report() {
    REPORT_REV=$(echo "$REQUEST_URL" | sed -r 's!result/([[:digit:]]+)/.+$!\1!')
    REPORT_RET=$(echo "$REQUEST_URL" | sed -r 's!result/[[:digit:]]+/(.+)$!\1!')
}

TEST_EXCHANGE="$PUSHER_ENV_BASE/test-xchg.txt"
TEST_EXCHANGE_1="$PUSHER_ENV_BASE/test-xchg-1.txt"

pusher_action_TESTCMD() {
    echo -n "$@" >"$TEST_EXCHANGE"
    cp -f "$_ACTIONS_CMD" "$TEST_EXCHANGE_1"
}

on_post_err_addon_ret() {
    local rev=$(echo "$REQUEST_URL" | sed -r 's!result/([[:digit:]]+)/.+$!\1!')
    local ret=$(echo "$REQUEST_URL" | sed -r 's!result/[[:digit:]]+/(.+)$!\1!')
    echo -n "$rev:$ret" >"$TEST_EXCHANGE"
    cp -f "$_ACTIONS_LOG" "$TEST_EXCHANGE_1"
}

# Preparation
fake_pending_report() {
    local rev=$1 ret=$2
    shift; shift
    new_file "$_ACTIONS_REPORT"
    new_file "$_ACTIONS_LOG"
    echo "$rev:$ret" >"$_ACTIONS_REPORT"
    echo "$@" >"$_ACTIONS_LOG"
}

prepare_addon() {
    local addon_dir="$PUSHER_HOME/addon"
    new_dir "$addon_dir"
    cat >"$addon_dir/start" <<EOF
#!/bin/bash
    echo -n "\$*" >$TEST_EXCHANGE
    while read; do
        echo "\$REPLY" >>$TEST_EXCHANGE_1
    done
EOF
    chmod a+rx "$addon_dir/start"
}

prepare_addon_ret_err() {
    local addon_dir="$PUSHER_HOME/addon-err"
    new_dir "$addon_dir"
    cat >"$addon_dir/start" <<EOF
#!/bin/bash
    echo "Bad"
    exit 1
EOF
    chmod a+rx "$addon_dir/start"
}

prepare_builtin() {
    local addon_dir="$PUSHER_BUILTIN_DIR/builtin"
    new_dir "$addon_dir"
    cat >"$addon_dir/start" <<EOF
#!/bin/bash
    echo -n "\$*" >$TEST_EXCHANGE
    while read; do
        echo "\$REPLY" >>$TEST_EXCHANGE_1
    done
EOF
    chmod a+rx "$addon_dir/start"
}

# Before case
actions_register TESTCMD
remove_pusher_folders
new_file "$TEST_EXCHANGE"
new_file "$TEST_EXCHANGE_1"

test_case_recover_report() {
    REPORT_REV=0
    REPORT_RET=0

    fake_pending_report 100 1 "Something"
    POST_ACTION=on_post_save_report RESPONSE="" actions_process
    expect_ok test $REPORT_REV -eq 100
    expect_ok test $REPORT_RET -eq 1
    expect_fail test -f "$_ACTIONS_LOG"
    expect_fail test -f "$_ACTIONS_REPORT"

    fake_pending_report 101 0 "Something"
    POST_ACTION=on_post_save_report RESPONSE="" actions_process
    expect_ok test $REPORT_REV -eq 101
    expect_ok test $REPORT_RET -eq 0
    expect_fail test -f "$_ACTIONS_LOG"
    expect_fail test -f "$_ACTIONS_REPORT"
    expect_ok test -f "$_ACTIONS_REVISION"
    expect_ok test "$(cat $_ACTIONS_REVISION)" == "101"
}

test_case_internal_cmd() {
    RESPONSE=$(cat <<EOF
1980::TESTCMD test command line
line1
line2
1980.
EOF) actions_process
    expect_ok test "$(cat $TEST_EXCHANGE)" == "test command line"
    cat "$TEST_EXCHANGE_1" | (
        local lines=0
        while read; do
            lines=$((lines+1))
            expect_ok test "$REPLY" == "line$lines"
        done
    )
    assert_ok $?
    expect_ok test -f "$_ACTIONS_REVISION"
    expect_ok test "$(cat $_ACTIONS_REVISION)" == "1980"
}

test_case_invoke_addon() {
    prepare_addon
    prepare_addon_ret_err

    RESPONSE=$(cat <<EOF
1880:addon:CMD test command line
line1
line2
1880.
1881:addon:CMD test command line
line3
line4
1881.
1882:non-existed:something
abc
1882.
1883:addon:CMD test command line
line5
1883.
EOF) actions_process
    expect_ok test "$(cat $TEST_EXCHANGE)" == "CMD test command line"
    cat "$TEST_EXCHANGE_1" | (
        local lines=0
        while read; do
            lines=$((lines+1))
            expect_ok test "$REPLY" == "line$lines"
        done
        expect_ok test $lines -eq 4
    )
    assert_ok $?
    expect_ok test -f "$_ACTIONS_REVISION"
    expect_ok test "$(cat $_ACTIONS_REVISION)" == "1881"
}

test_case_invoke_addon_err() {
    prepare_addon_ret_err

    new_file "$TEST_EXCHANGE"
    new_file "$TEST_EXCHANGE_1"

    POST_ACTION=on_post_err_addon_ret RESPONSE=$(cat <<EOF
1780:addon-err:CMD test command line
line1
line2
1780.
EOF) actions_process
    expect_ok test "$(cat $TEST_EXCHANGE)" == "1780:1"
    expect_ok test "$(cat $TEST_EXCHANGE_1)" == "Bad"
}

test_case_invoke_builtin() {
    prepare_builtin

    RESPONSE=$(cat <<EOF
1980:builtin:CMD builtin args
line1
line2
1980.
EOF) actions_process
    expect_ok test "$(cat $TEST_EXCHANGE)" == "CMD builtin args"
    cat "$TEST_EXCHANGE_1" | (
        local lines=0
        while read; do
            lines=$((lines+1))
            expect_ok test "$REPLY" == "line$lines"
        done
        expect_ok test $lines -eq 2
    )
    assert_ok $?
    expect_ok test -f "$_ACTIONS_REVISION"
    expect_ok test "$(cat $_ACTIONS_REVISION)" == "1980"
}

TEST_CASES="recover_report internal_cmd invoke_addon invoke_addon_err invoke_builtin"