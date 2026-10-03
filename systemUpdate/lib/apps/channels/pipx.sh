#!/usr/bin/env bash
# pipx channel — pipx applications

CHANNEL_ID="pipx"
CHANNEL_LABEL="pipx applications"
CHANNEL_PRESENT="command -v pipx"
CHANNEL_REPORT="pipx list --short"
CHANNEL_UPDATE="pipx upgrade-all"
