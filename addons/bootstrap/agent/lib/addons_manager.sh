_ADDONS_RETIRE_DIR="$PUSHER_EXEC_BASE/retired"
_ADDONS_UPGRADE_DIR="$PUSHER_EXEC_BASE/upgrades"
_ADDONS_STAGE_DIR="$PUSHER_EXEC_BASE/stage"

PUSHER_ADDON_CACHE="$PUSHER_CACHE_BASE/addons"
PUSHER_BUILTIN_DIR="$PUSHER_LIB_BASE/addons"

# Checking Digest
_addons_check_digest() {
    local file="$1" digest=$2
    if [ -f "$file" ]; then
        local local_digest
        local_digest=$(md5sum -b "$file" | sed -r 's/^([[:xdigit:]]+).*$/\1/')
        [ "$local_digest" == "$digest" ] && return 0
    fi
    return 1
}

# Download addon package
_addons_download() {
    local pkgfile="$1" digest=$2 url="$3"

    for ((i=0; i<3; i=i+1)); do
        _addons_check_digest "$pkgfile" $digest && return 0
        ACCEPTS="application/binary" request GET "$url" -o "$pkgfile" || continue
    done

    _addons_check_digest "$pkgfile" $digest && return 0
    return 1
}

# Install addon
_addons_install() {
    local pkgfile="$1" name=$2 ret
    [ -f "$pkgfile" ] || return 1

    new_dir "$_ADDONS_STAGE_DIR" || (echo "Unable to create folder: $_ADDONS_STAGE_DIR" && return 1)
    pushd "$_ADDONS_STAGE_DIR" || return 1
    tar -zxf "$pkgfile"
    ret=$?
    popd
    [ $ret -eq 0 ] || (echo "Unable to unpack addon $(basename $pkgfile)" && return 1)

    if ! [ -x "$_ADDONS_STAGE_DIR/start" ]; then
        echo "Invalid package of addon $name"
        safe_rm_all "$_ADDONS_STAGE_DIR"
        return 1
    fi

    mkdir -p "$_ADDONS_UPGRADE_DIR"
    safe_rm_all "$_ADDONS_UPGRADE_DIR/$name"
    mv -f "$_ADDONS_STAGE_DIR" "$_ADDONS_UPGRADE_DIR/$name" || return 1
}

# Uninstall addon
_addons_uninstall() {
    local addon="$1"
    safe_rm_all "$_ADDONS_UPGRADE_DIR/$addon"
    safe_rm_all "$_ADDONS_RETIRE_DIR/$addon"
    safe_rm_all "$PUSHER_HOME/$addon"
}

# Clean up all retired packages or recover failed upgrade transactions
_addons_clean_retired() {
    for addon in $(find "$_ADDONS_RETIRE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
        local name=$(basename "$addon")
        if [ -d "$PUSHER_HOME/$name" ]; then
            safe_rm_all "$_ADDONS_RETIRE_DIR/$name"
        else
            mkdir -p "$PUSHER_HOME"
            mv -f "$_ADDONS_RETIRE_DIR/$name" "$PUSHER_HOME/"
        fi
    done
}

# Try to apply packages from upgrades to current
addons_apply_upgrades() {
    _addons_clean_retired
    mkdir -p "$PUSHER_HOME"
    for addon in $(find "$_ADDONS_UPGRADE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do
        local name=$(basename "$addon")
        if [ -d "$PUSHER_HOME/$name" ]; then
            safe_rm_all "$_ADDONS_RETIRE_DIR/$name"
            mv -f "$PUSHER_HOME/$name" "$_ADDONS_RETIRE_DIR/" || continue
        fi
        mv -f "$_ADDONS_UPGRADE_DIR/$name" "$PUSHER_HOME/" &&
            safe_rm_all "$_ADDONS_RETIRE_DIR/$name"
    done
    _addons_clean_retired
}

pusher_action_ADDON_ADD() {
    local addon=$1 ver=$2 digest=$3 url="$4"
    if [ -z "$addon" ] || [ -z "$ver" ] || [ -z "$digest" ] || [ -z "$url" ]; then
        echo "Usage: ADDON name version MD5-digest url"
        return 1
    fi

    mkdir -p "$PUSHER_ADDON_CACHE"
    local pkgfile="$PUSHER_ADDON_CACHE/$1-$2.addon.tgz"
    _addons_download $pkgfile $digest "$url" || return 1
    _addons_install $pkgfile $addon || return 1
    addons_apply_upgrades
}

pusher_action_ADDON_DEL() {
    for addon in "$@" ; do
        _addons_uninstall "$addon"
    done
    return 0
}

actions_register ADDON_ADD ADDON_DEL
