#!/bin/sh
# Report defconfig lines that did not survive into output/.config
# (e.g. symbols dropped because a dependency is unmet).
cd "$(dirname "$0")/.."
grep -v '^$' br2-skylark/configs/skylark_bbb_defconfig | grep -v '^# BR2_.*is not set' | grep -v '^#' |
while IFS= read -r l; do
    grep -qxF "$l" output/.config || {
        k=${l%%=*}
        echo "MISMATCH: $l -> $(grep -e "^$k=" -e "# $k is" output/.config)"
    }
done
echo "check done"
