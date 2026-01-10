#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title bwrc-nx-tunnel
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName jimfangx

# Documentation:
# @raycast.description start-bwrc-nomachine-ssh-tunnel
# @raycast.author jimfang
# @raycast.authorURL https://raycast.com/airfusion

launchctl load -w ~/com.jimfangx.ssh-tunnel-bwrcrdsl-nomachine.plist

echo 'Done!'

