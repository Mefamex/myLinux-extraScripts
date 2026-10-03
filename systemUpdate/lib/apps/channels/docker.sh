#!/usr/bin/env bash
# docker channel — Docker images (report only)

CHANNEL_ID="docker"
CHANNEL_LABEL="Docker images"
CHANNEL_PRESENT="docker info"
CHANNEL_REPORT="docker images --format '{{.Repository}}:{{.Tag}}'"
CHANNEL_UPDATE=""
