PUSHER_CONF_BASE="$TESTS_WORK_DIR/$TEST_CASE/etc/pusher"
PUSHER_CACHE_BASE="$TESTS_WORK_DIR/$TEST_CASE/var/cache/pusher"
PUSHER_EXEC_BASE="$TESTS_WORK_DIR/$TEST_CASE/var/lib/pusher"
PUSHER_LIB_BASE="$TESTS_WORK_DIR/$TEST_CASE/usr/lib/pusher"
PUSHER_ENV_BASE="$TESTS_WORK_DIR/$TEST_CASE/var/run/pusher"

PUSHER_HOME="$PUSHER_EXEC_BASE/current"

SRC_BASE="$TESTS_SCRIPT_DIR/.."

remove_pusher_folders() {
    safe_rm_all "$PUSHER_CONF_BASE"
    safe_rm_all "$PUSHER_CACHE_BASE"
    safe_rm_all "$PUSHER_EXEC_BASE"
    safe_rm_all "$PUSHER_LIB_BASE"
    safe_rm_all "$PUSHER_ENV_BASE"
}
