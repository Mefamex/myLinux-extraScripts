#!/usr/bin/env bash
# deno channel — Deno runtime

CHANNEL_ID="deno"
CHANNEL_LABEL="Deno"
CHANNEL_PRESENT="command -v deno"
# `deno --version` prints three lines (deno, v8, typescript); the report shows
# only the first. The output is tiny, so the pipe cannot SIGPIPE under pipefail.
CHANNEL_REPORT="deno --version | head -1"
CHANNEL_UPDATE="deno upgrade"
