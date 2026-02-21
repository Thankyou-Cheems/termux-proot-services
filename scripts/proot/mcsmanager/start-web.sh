#!/bin/bash
set -e

cd /opt/mcsmanager/web || exit 1
exec node --max-old-space-size=8192 --enable-source-maps app.js
