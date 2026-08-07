#!/bin/bash
echo "$1" > /tmp/eh-pkg-file.txt
quickshell ipc call event-horizon-local-install openPkg
