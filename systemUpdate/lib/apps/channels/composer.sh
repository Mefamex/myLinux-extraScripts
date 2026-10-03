#!/usr/bin/env bash
# composer channel — Composer global packages

CHANNEL_ID="composer"
CHANNEL_LABEL="Composer global packages"
CHANNEL_PRESENT="command -v composer"
CHANNEL_REPORT="composer global show -N"
CHANNEL_UPDATE="composer global update"
