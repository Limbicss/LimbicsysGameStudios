#!/usr/bin/env bash
# One-time setup per clone (works in Git Bash on Windows): bash hooks/install.sh
cd "$(git rev-parse --show-toplevel)" || exit 1
chmod +x hooks/pre-commit hooks/commit-msg hooks/pre-push hooks/adapters/*.sh hooks/lib/*.sh 2>/dev/null
git config core.hooksPath hooks && echo "core.hooksPath = hooks  (git hooks active)"
