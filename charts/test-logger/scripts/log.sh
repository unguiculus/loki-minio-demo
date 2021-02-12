#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

main() {
    local log_type="${1:?Log type must be specified (json or logfmt}"

    local counter=0
    while true; do
        local timestamp
        timestamp=$(date -Is)

        local level
        if [[ $((counter % 5)) == 0 ]]; then
            level=error
        else
            level=info
        fi

        "print_${log_type}_msg"

        ((++counter))

        sleep 0.5
    done
}

print_json_msg() {
    echo "{\"ts\": \"$timestamp\", \"level\": \"$level\", \"msg\": \"Test message in json format on $level level ($counter)\"}"
}

print_logfmt_msg() {
    echo "ts=$timestamp level=$level msg=\"Test message in logfmt format on $level level $counter\""
}

main "$@"
