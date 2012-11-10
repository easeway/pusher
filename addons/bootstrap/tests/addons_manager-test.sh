source "$TESTS_SCRIPT_DIR/test_env.sh"

source "$SRC_BASE/agent/lib/functions.sh"

# Fake functions
actions_register() {
    return 0
}

request() {
    REQUEST_COUNT=$((REQUEST_COUNT+1))

    local out=0 outfile=""
    for opt in "$@"; do
        [ $out -eq 1 ] && outfile="$opt" && break
        [ "$opt" == "-o" ] && out=1 || out=0
    done
    [ -n "$outfile" ] && [ -n "$ADDON_PKGFILE" ] && [ -f "$ADDON_PKGFILE" ] \
        && cp -f "$ADDON_PKGFILE" "$outfile"
}

source "$SRC_BASE/agent/lib/addons_manager.sh"

# Preparation
digest() {
    md5sum -b "$1" | sed -r 's/^([[:xdigit:]]+).+$/\1/'
}

make_addon_package() {
    local addon_dir="$1"
    ADDON_PKGFILE="$2"
    safe_rm_all "$ADDON_PKGFILE"
    tar -C "$addon_dir" -zcf "$ADDON_PKGFILE" .
    ADDON_DIGEST=$(digest "$ADDON_PKGFILE")
}

prepare_addon_package() {
    local addon_dir="$TESTS_WORK_DIR/pusher/addon"
    new_dir "$addon_dir"
    cat >"$addon_dir/start" <<EOF
#!/bin/sh
echo "Hello World!"
EOF
    chmod a+rx "$addon_dir/start"
    cat >"$addon_dir/version" <<EOF
VERSION=0.1
EOF
    make_addon_package "$addon_dir" "$TESTS_WORK_DIR/pusher/addon.pkg"
}

prepare_invalid_package() {
    local addon_dir="$TESTS_WORK_DIR/pusher/bad-addon"
    new_dir "$addon_dir"
    cat >"$addon_dir/start" <<EOF
#!/bin/sh
echo "Hello World!"
EOF
    make_addon_package "$addon_dir" "$TESTS_WORK_DIR/pusher/bad-addon.pkg"
}

test_case_digest_check() {
    local file="$TESTS_WORK_DIR/addons_manager_digest_check.tmp"
    new_file "$file"
    echo "Hello World!" >"$file"

    local digest
    digest=$(digest "$file")
    assert_ok $?
    expect_fail _addons_check_digest "$file"
    expect_fail _addons_check_digest "$file" "somevalue"
    expect_ok _addons_check_digest "$file" "$digest"
}

test_case_download() {
    remove_pusher_folders
    prepare_addon_package

    local pkgfile="$PUSHER_ADDON_CACHE/addon.addon.tgz"
    mkdir -p "$PUSHER_ADDON_CACHE"

    REQUEST_COUNT=0
    expect_ok _addons_download "$pkgfile" $ADDON_DIGEST "someurl"
    expect_ok test -f "$pkgfile"
    expect_ok test $REQUEST_COUNT -eq 1
    expect_ok test "$(digest $pkgfile)" == "$ADDON_DIGEST"

    expect_ok _addons_download "$pkgfile" $ADDON_DIGEST "someurl"
    expect_ok test $REQUEST_COUNT -eq 1

    echo "Hello World!" >"$pkgfile"
    expect_ok _addons_download "$pkgfile" $ADDON_DIGEST "someurl"
    expect_ok test $REQUEST_COUNT -eq 2
    expect_ok test -f "$pkgfile"
    expect_ok test "$(digest $pkgfile)" == "$ADDON_DIGEST"
}

test_case_install() {
    remove_pusher_folders
    prepare_addon_package

    local pkgfile="$PUSHER_ADDON_CACHE/addon-1.0.addon.tgz"

    REQUEST_COUNT=0
    expect_ok pusher_action_ADDON_ADD addon 1.0 $ADDON_DIGEST "someurl"
    expect_ok test -f "$pkgfile"
    expect_ok test $REQUEST_COUNT -eq 1
    expect_ok test "$(digest $pkgfile)" == "$ADDON_DIGEST"
    expect_ok test -d "$PUSHER_HOME/addon"
    expect_ok test -x "$PUSHER_HOME/addon/start"
    expect_fail test -d "$_ADDONS_UPGRADE_DIR/addon"
    expect_fail test -d "$_ADDONS_RETIRE_DIR/addon"
    expect_fail test -d "$_ADDONS_STAGE_DIR"

    prepare_invalid_package
    local output
    output=$(pusher_action_ADDON_ADD bad-addon 1.0 $ADDON_DIGEST "someurl")
    assert_fail $?
    echo "$output" | grep "Invalid package"
    assert_ok $?
    expect_fail test -d "$_ADDONS_STAGE_DIR"
}

test_case_uninstall() {
    remove_pusher_folders
    prepare_addon_package

    expect_ok pusher_action_ADDON_ADD addon 1.0 $ADDON_DIGEST "someurl"
    expect_ok test -d "$PUSHER_HOME/addon"
    expect_ok test -x "$PUSHER_HOME/addon/start"
    expect_ok pusher_action_ADDON_DEL addon
    expect_fail test -d "$PUSHER_HOME/addon"
}

test_case_upgrades() {
    remove_pusher_folders

    new_file "$_ADDONS_UPGRADE_DIR/new_addon/start"

    expect_ok addons_apply_upgrades
    expect_ok test -d "$PUSHER_HOME/new_addon"
    expect_ok test -f "$PUSHER_HOME/new_addon/start"
    expect_fail test -d "$_ADDONS_UPGRADE_DIR/new_addon"
    expect_fail test -d "$_ADDONS_RETIRE_DIR/new_addon"

    new_file "$_ADDONS_UPGRADE_DIR/new_addon/start"
    echo -n "1" >"$_ADDONS_UPGRADE_DIR/new_addon/start"

    expect_ok addons_apply_upgrades
    expect_ok test -d "$PUSHER_HOME/new_addon"
    expect_ok test -f "$PUSHER_HOME/new_addon/start"
    expect_fail test -d "$_ADDONS_UPGRADE_DIR/new_addon"
    expect_fail test -d "$_ADDONS_RETIRE_DIR/new_addon"
    expect_ok test "$(cat $PUSHER_HOME/new_addon/start)" == "1"
}

test_case_rollback() {
    remove_pusher_folders

    new_file "$_ADDONS_RETIRE_DIR/addon/start"

    expect_ok addons_apply_upgrades
    expect_ok test -d "$PUSHER_HOME/addon"
    expect_ok test -f "$PUSHER_HOME/addon/start"
    expect_fail test -d "$_ADDONS_RETIRE_DIR/addon"
    expect_fail test -d "$_ADDONS_UPGRADE_DIR/addon"
}

test_case_conflict() {
    remove_pusher_folders

    new_file "$_ADDONS_RETIRE_DIR/addon/start"
    echo -n "0" >"$_ADDONS_RETIRE_DIR/addon/start"

    new_file "$_ADDONS_UPGRADE_DIR/addon/start"
    echo -n "1" >"$_ADDONS_UPGRADE_DIR/addon/start"

    expect_ok addons_apply_upgrades
    expect_ok test -d "$PUSHER_HOME/addon"
    expect_ok test -f "$PUSHER_HOME/addon/start"
    expect_fail test -d "$_ADDONS_RETIRE_DIR/addon"
    expect_fail test -d "$_ADDONS_UPGRADE_DIR/addon"
    expect_ok test "$(cat $PUSHER_HOME/addon/start)" == "1"
}

TEST_CASES="digest_check download install uninstall upgrades rollback conflict"
