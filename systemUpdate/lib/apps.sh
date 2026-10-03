#!/usr/bin/env bash
#
# lib/apps.sh — source file, NOT meant to be run directly
#
# systemUpdate — apps.sh
#
# Thin wrapper that loads the modular app runner from lib/apps/runner.sh.
# The actual channel definitions live in lib/apps/channels/*.sh
# Sort order is defined in lib/apps/sort.conf.

# shellcheck source=lib/apps/runner.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/apps/runner.sh"
