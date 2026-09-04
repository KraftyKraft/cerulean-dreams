#!/bin/sh
set -eu

git config --local core.hooksPath .githooks
echo "Git hooks enabled."