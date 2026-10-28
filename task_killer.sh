#!/bin/bash

echo "🔍 Bazel va run.sh jarayonlari qidirilmoqda..."
ps aux | grep -E "bazel|run.sh" | grep -v grep

echo "💥 Jarayonlarni to'xtatish..."
pkill -9 -f bazel
pkill -9 -f run.sh

echo "✅ Barcha tiqilib qolgan tasklar o'ldirildi!"
