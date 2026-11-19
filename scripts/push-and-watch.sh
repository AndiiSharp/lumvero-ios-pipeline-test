#!/usr/bin/env bash
# Nach Freigabe des gh-Scopes "workflow": Workflow-Commit pushen, Lauf beobachten, Artefakte holen.
set -euo pipefail
cd "$(dirname "$0")/.."
gh auth status 2>&1 | grep -q "'workflow'" || { echo "gh-Token hat noch keinen workflow-Scope"; exit 2; }
git -c credential.helper= -c credential.helper='!gh auth git-credential' push origin main
sleep 10
RUN_ID=$(gh run list -R AndiiSharp/lumvero-ios-pipeline-test -L 1 --json databaseId -q '.[0].databaseId')
echo "Run: https://github.com/AndiiSharp/lumvero-ios-pipeline-test/actions/runs/$RUN_ID"
gh run watch "$RUN_ID" -R AndiiSharp/lumvero-ios-pipeline-test --exit-status || true
gh run view "$RUN_ID" -R AndiiSharp/lumvero-ios-pipeline-test
rm -rf "results/run-$RUN_ID" && gh run download "$RUN_ID" -R AndiiSharp/lumvero-ios-pipeline-test -D "results/run-$RUN_ID"
