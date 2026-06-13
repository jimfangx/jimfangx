#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Hide Dock
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Hides MacOS Dock by setting hover delay to 1000s = 17m
# @raycast.author jimfang
# @raycast.authorURL https://raycast.com/airfusion

defaults write com.apple.dock autohide -bool true && killall Dock
defaults write com.apple.dock autohide-delay -float 1000 && killall Dock
defaults write com.apple.dock no-bouncing -bool TRUE && killall Dock
