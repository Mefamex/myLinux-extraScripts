#!/usr/bin/env bash
#
# lib/sections/00_privacy.sh — sourced file, DO NOT RUN DIRECTLY
#
# systemReport — 00_privacy
#
# A report is shareable, but not ready-made. This section states which files
# contain what, so the developer remembers to check, and so whoever receives the
# report sees the warning before reading any of it.
#
# Depends on: nothing

section_00() {
	cat <<'TEXT'
This report may CONTAIN SENSITIVE DATA. Review the files below before
uploading it anywhere (a forum, an issue tracker, a chat):

  05_network.txt       IP/MAC addresses, open ports, DNS servers
  01_system.txt        host name
  06_packages.txt      full package list (a map of your installed software)
  08_configuration.txt /etc/environment, fstab UUIDs, modprobe rules
  02_hardware.txt      RAM and disk serial numbers
  VERSION.txt          host name and kernel version
  terminal_log.txt     the terminal output of this run (contains all of the above)

The two files that matter most are 05_network.txt and 08_configuration.txt.
If you do not want to edit anything, deleting just those two makes the
rest safe to share in a broad sense. It is still your call.
TEXT
}
