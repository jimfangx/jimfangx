#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Kill Global Protect
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Kill Global Protect Daemon
# @raycast.author airfusion
# @raycast.authorURL https://raycast.com/airfusion

sudo sed -i '' -e "s/true/false/g" /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist

launchctl unload /Library/LaunchAgents/com.paloaltonetworks.gp.pangp*

echo 'Done!'
