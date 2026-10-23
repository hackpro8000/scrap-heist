#!/usr/bin/env bash
# Renders a model from four angles side by side, for checking work without
# a full checkpoint.
#
#   scripts/view-model.sh Zapper /tmp/zapper.png

set -euo pipefail

name="${1:?model name required}"
out="${2:?output png required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
turntable="${root}/art/models/${name}/turntable"

"${root}/tools/modelkit/bin/modelkit-linux-x64" "${root}/art/models/${name}" --turntable 60 >/dev/null
ffmpeg -loglevel error -y -i "${turntable}/0000.png" -i "${turntable}/0015.png" -i "${turntable}/0030.png" -i "${turntable}/0045.png" -filter_complex hstack=4 "${out}"
rm -rf "${turntable}"
