#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mode="${1:-run}"
case "$mode" in
    run|--debug|--logs|--telemetry|--verify) ;;
    *) print -u2 "Usage: $0 [--debug|--logs|--telemetry|--verify]"; exit 2 ;;
esac
if pgrep -x FinderSearch >/dev/null; then
    pkill -x FinderSearch
fi
./scripts/build.sh
app="$PWD/dist/FinderSearch.app"
case "$mode" in
    --debug) lldb -- "$app/Contents/MacOS/FinderSearch" ;;
    --logs|--telemetry)
        /usr/bin/open -n "$app"
        /usr/bin/log stream --info --style compact --predicate 'process == "FinderSearch"'
        ;;
    --verify)
        /usr/bin/open -n "$app"
        sleep 1
        pgrep -x FinderSearch
        ;;
    run) /usr/bin/open -n "$app" ;;
esac
