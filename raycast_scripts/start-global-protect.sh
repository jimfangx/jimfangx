#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Start Global Protect
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Start Global Protect Daemon
# @raycast.author airfusion
# @raycast.authorURL https://raycast.com/airfusion

launchctl load /Library/LaunchAgents/com.paloaltonetworks.gp.pangp*

echo "Done!"

