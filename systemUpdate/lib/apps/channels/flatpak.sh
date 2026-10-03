#!/usr/bin/env bash
# flatpak channel — Flatpak apps (report only)

CHANNEL_ID="flatpak"
CHANNEL_LABEL="Flatpak apps"
CHANNEL_PRESENT="command -v flatpak"
CHANNEL_REPORT="flatpak list --app --columns=application"
CHANNEL_UPDATE=""
