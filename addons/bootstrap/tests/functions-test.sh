source "$TESTS_SCRIPT_DIR/test_env.sh"

source "$SRC_BASE/agent/lib/functions.sh"

test_case_extract_val() {
    local fn="$TESTS_WORK_DIR/extract_val_from_file-$$.tmp" val
    cat >"$fn" <<EOF

NAME:123:+-
Something
EOF

    val=$(extract_val '^([[:alnum:]]+):.+$' "$fn")
    assert_ok $?
    expect_ok test "$val" == "NAME"

    val=$(extract_val '^[[:alnum:]]+:([[:digit:]]+).*$' "$fn")
    assert_ok $?
    expect_ok test "$val" == "123"

    val=$(extract_val '^([[:alnum:]]+):.+$' <"$fn")
    assert_ok $?
    expect_ok test "$val" == "NAME"

    val=$(extract_val '^[[:alnum:]]+:([[:digit:]]+).*$' <"$fn")
    assert_ok $?
    expect_ok test "$val" == "123"

    val=$(DEFAULT_VAL=DEF extract_val '^ABC([[:digit:]]+).+$' "$fn")
    assert_ok $?
    expect_ok test "$val" == "DEF"
}

if [ "$TEST_CASE" == "safe_rm" ]; then
    rm() {
        for opt in "$@"; do
            [ "${opt:0:1}" == "-" ] && continue
            RM_PARAM="$opt"
        done
    }
fi

test_case_safe_rm() {
    RM_PARAM=""
    safe_rm /abc
    expect_ok test -z "$RM_PARAM"

    RM_PARAM=""
    safe_rm /pusher
    expect_ok test -z "$RM_PARAM"

    RM_PARAM=""
    safe_rm /abc/pusher
    expect_ok test -z "$RM_PARAM"

    RM_PARAM=""
    safe_rm /abc/pusher/file
    expect_ok test "$RM_PARAM" == "/abc/pusher/file"
}

TEST_CASES="extract_val safe_rm"
