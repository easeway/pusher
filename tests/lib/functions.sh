print_stack() {
    local n=${#BASH_LINENO[@]} s=$1
    [ -z "$s" ] && s=1 || s=$((s+1))
    for ((i=$s; i+1<$n; i=i+1)); do
        echo "${BASH_SOURCE[$i+1]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}"
    done
}

test_fail() {
    echo "TEST-FAIL[$TEST_CASE]: $*" >&2
    print_stack 1 >&2
    exit 1
}

assert_ok() {
    local ret=$1
    shift
    [ $ret -eq 0 ] || test_fail "ASSERT_OK($1) $*"
}

assert_fail() {
    local ret=$1
    [ $ret -ne 0 ] || test_fail "ASSERT_FAIL $*"
}

expect_ok() {
    "$@"
    assert_ok $? "$@"
}

expect_fail() {
    "$@"
    assert_fail $? "$@"
}