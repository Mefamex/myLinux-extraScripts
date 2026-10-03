#!/usr/bin/env bash
# dotnet channel — .NET global tools (report only)

CHANNEL_ID="dotnet"
CHANNEL_LABEL=".NET global tools"
CHANNEL_PRESENT="command -v dotnet"
CHANNEL_REPORT="dotnet tool list --global"
CHANNEL_UPDATE=""
