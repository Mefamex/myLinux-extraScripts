#!/usr/bin/env bash
# npm channel — NPM global packages

CHANNEL_ID="npm"
CHANNEL_LABEL="NPM global packages"
CHANNEL_PRESENT="command -v npm"
CHANNEL_REPORT="npm outdated -g --depth=0"
CHANNEL_UPDATE="npm -g update"
