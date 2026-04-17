# mc-server-largepage-script
a simple bash script for a few friends to automate detecting, setting and/or calculating large pages for java MC.

To use:
>Set LARGE_PAGE_MB at the top to the exact value of your -Xmx value in the server. (I would also recommend keeping the same -Xmx and -Xms value.)

>Put this script in the server folder where your server launch script is.

>Rename STARTSERVER_SCRIPT to the exact file name of your server launch script.

>Add the JVM argument flag `-XX:+UseLargePages` to your server.

>Launch via ./server_largepage.sh

If it doesn't run, check if the script is executable. You can do `chmod +x server_largepage.sh` to do that.

If something doesn't work right please let me know.

This script is very basic, it is meant to be.

Also, large pages are best used with G1GC, not ZGC. ZGC uses unimaginably more memory then G1GC, and would require probably 1-2 gigs of extra headroom. If you insist on ZGC, edit the HEADROOM variable to be 1024 or 2048.
