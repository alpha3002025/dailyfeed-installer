#!/bin/bash

echo "🗑️🗑️🗑️ Uninstalling DailyFeed (Hybrid Mode) 🗑️🗑️🗑️"
echo ""

echo "=== Step 1: Uninstall Applications ==="
cd dailyfeed-app-helm
source uninstall-local.sh
cd ..
echo ""

echo "=== Step 2: Uninstall Infrastructure ==="
cd dailyfeed-infrastructure
source uninstall-local-hybrid.sh
cd ..
echo ""

echo "✅✅✅ DailyFeed Uninstall Complete ✅✅✅"
echo ""
