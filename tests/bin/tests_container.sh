TEST_SCRIPT="$2"
TEST_CASE="$3"

export TESTS_SCRIPT_DIR=$(dirname "$TEST_SCRIPT")

source "$TESTS_LIB_DIR/functions.sh"
source "$TEST_SCRIPT"

log() {
    echo "LOG: $*"
}

container_list() {
    echo $TEST_CASES
}

container_run() {
    echo "TEST ${TEST_CASE}"
    test_case_${TEST_CASE}
}

container_$1
