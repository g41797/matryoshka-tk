#!/bin/bash

set -e

cd "$(dirname "$0")/.."

date

zig build core -freference-trace --summary all -Doptimize=Debug

date
