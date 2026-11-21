#!/bin/sh
# Store SOLOIST_API_KEY in Soloist's data directory before the daemon starts.
# Soloist uses the stored key when --api-key is absent, so the key survives
# restarts and never appears in the command line (ps). An explicit --api-key/-k
# still overrides the stored key for that run.
set -eu

data_dir=

# The data directory must match the one the daemon uses; otherwise the key
# would be stored somewhere the daemon never looks.
parse_data_dir() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -D|--data-dir)
                shift
                if [ "$#" -gt 0 ]; then
                    data_dir=$1
                    shift
                fi
                continue
                ;;
            --data-dir=*)
                data_dir=${1#--data-dir=}
                ;;
            -D=*)
                data_dir=${1#-D=}
                ;;
            -D?*)
                data_dir=${1#-D}
                ;;
        esac
        shift
    done
}

store_key=false
if [ -n "${SOLOIST_API_KEY:-}" ]; then
    store_key=true
    for arg in "$@"; do
        case "$arg" in
            # The caller supplied a key for this run; do not overwrite the
            # stored one.
            -k|--api-key|-k=*|--api-key=*|-k?*)
                store_key=false
                break
                ;;
            # Commands that handle the key themselves or do not need it.
            setup-api-key|ctl|-h|--help|-V|--version)
                store_key=false
                break
                ;;
        esac
    done
fi

if [ "$store_key" = true ]; then
    parse_data_dir "$@"
    # The stored key and its directory are private to the container user.
    if [ -n "$data_dir" ]; then
        (umask 077; printf '%s' "$SOLOIST_API_KEY" | /app/soloist setup-api-key --data-dir "$data_dir")
    else
        (umask 077; printf '%s' "$SOLOIST_API_KEY" | /app/soloist setup-api-key)
    fi
    # The daemon reads the stored key; do not keep the secret in its
    # environment.
    unset SOLOIST_API_KEY
fi

exec /app/soloist "$@"
