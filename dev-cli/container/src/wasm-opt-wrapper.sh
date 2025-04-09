#!/bin/bash
echo "Wrapper called with: $@" >&2
args=()
for arg in "$@"; do
  if [[ "$arg" != "--enable-call-indirect-overlong" && "$arg" != "--enable-bulk-memory-opt" ]]; then
    args+=("$arg")
  fi
done
echo "Filtered args: ${args[@]}" >&2
exec /emsdk/upstream/bin/wasm-opt-original "${args[@]}"