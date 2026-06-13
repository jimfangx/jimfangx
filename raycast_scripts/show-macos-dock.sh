#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Show Dock
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Show MacOS dock by restoring autohide delay
# @raycast.author jimfang
# @raycast.authorURL https://raycast.com/airfusion

defaults write com.apple.dock autohide -bool false && killall Dock
defaults delete com.apple.dock autohide-delay && killall Dock
defaults write com.apple.dock no-bouncing -bool FALSE && killall Dock

