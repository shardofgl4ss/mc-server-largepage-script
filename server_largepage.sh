#!/bin/bash
set -eou pipefail

readonly LARGE_PAGE_MB=4096
readonly LARGE_PAGE_JVM_HEADROOM_MB=512
readonly LARGE_PAGE_TOTAL_MB=$(("$LARGE_PAGE_MB" + "$LARGE_PAGE_JVM_HEADROOM_MB"))
readonly LARGE_PAGE_COUNT=$(("$LARGE_PAGE_TOTAL_MB" / 2))

readonly STARTSERVER_SCRIPT="startserver-java9.sh"

total_hugepage()
{
        awk '/^HugePages_Total:/ {print $2}' /proc/meminfo
}
free_hugepage()
{
        awk '/^HugePages_Free:/ {print $2}' /proc/meminfo
}

sanity_check()
{
        if [ "$(awk '/^Hugepagesize:/ {print $2}' /proc/meminfo)" -ne 2048 ]; then
                echo "large pages are not configured on your system to 2MiB!"
                exit
        fi
        if [ "$(zgrep 'CONFIG_COMPACTION=' /proc/config.gz | cut -d= -f2)" != "y" ]; then
                echo "compaction not supported by kernel! hugepages must be set at boot!"
                exit
        fi
}

set_largepages()
{
        local pages_to_set="$1"

        sync # flushes some caches back to disk, helps compaction and is harmless.
        echo 1 | sudo tee /proc/sys/vm/compact_memory # triggers kernel memory compaction to help find a empty enough spot in memory.
        sudo sysctl -w vm.nr_hugepages="$pages_to_set" # finds hugepages if there is enough non-fragmented physical memory.
}

reset_largepages()
{
        local mode="$1"
        local reset_back_pages="$2"

        case "$mode" in
        1)
                sudo sysctl -w vm.nr_hugepages=0
                ;;
        2)
                sudo sysctl -w vm.nr_hugepages="$reset_back_pages"
                ;;
        esac
        exit 0
}

main()
{
        sanity_check
        echo "A password will be prompted for enabling large pages if needed."

        local hugepages_count="$(total_hugepage)"
        local hugepages_free="$(free_hugepage)"
        reset_on_exit=0                         # These two cannot be local due to the trap.
        reset_back_pages="$hugepages_count"

        trap 'reset_largepages "$reset_on_exit" "$reset_back_pages"' SIGINT

        if [ "$hugepages_free" -ge "$LARGE_PAGE_COUNT" ]; then
                echo "large pages already configured and with enough space."
        elif [ "$hugepages_count" -eq 0 ]; then
                echo "large pages not configured. configuring."

                set_largepages "$LARGE_PAGE_COUNT" 
                reset_on_exit=1

                if [ "$(total_hugepage)" -ne "$LARGE_PAGE_COUNT" ]; then
                        echo "failed to set the requested amount of HugeTLB pages! you may need to reboot or close other programs first!"
                        sudo sysctl -w vm.nr_hugepages=0
                        exit 1
                fi
        elif [ "$hugepages_count" -gt 0 -a "$hugepages_free" -lt "$LARGE_PAGE_COUNT" ]; then
                local new_largepage_request=$((("$LARGE_PAGE_COUNT" - "$hugepages_free") + "$hugepages_count"))

                set_largepages "$new_largepage_request"
                reset_on_exit=2

                if [ "$(total_hugepage)" -ne "$new_largepage_request" ]; then
                        echo "failed to set the requested amount of HugeTLB pages! you may need to reboot or close other programs first!"
                        sudo sysctl -w vm.nr_hugepages="$hugepages_count"
                        exit 1
                fi
        fi


        ./"$STARTSERVER_SCRIPT"

        reset_largepages "$reset_on_exit" "$reset_back_pages"
}

main
