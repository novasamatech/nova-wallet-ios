#!/usr/bin/env bash
set -euo pipefail

# Ensure Homebrew paths are in PATH for Xcode/non-login shells
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

WORK_DIR="novawallet"
TEMPLATES_DIR="$WORK_DIR/SourceryTemplates"
SOURCES_DIR="$WORK_DIR/SourceryTemplates"

echo "Sourcery Work Directory = $WORK_DIR"

#check if env-vars.sh exists
if [ -f $WORK_DIR/env-vars.sh ]
then
source $WORK_DIR/env-vars.sh
fi
#no `else` case needed if the CI works as expected

OUT_FILE="$WORK_DIR/CIKeys.generated.swift"
echo "Sourcery Output File = $OUT_FILE"

mint run krzysztofzablocki/Sourcery@2.2.7 sourcery \
 --templates $TEMPLATES_DIR \
 --sources $SOURCES_DIR \
 --output $OUT_FILE \
 --args mercuryoSecretKey=${MERCURYO_PRODUCTION_SECRET},mercuryoTestSecretKey=${MERCURYO_TEST_SECRET},acalaAuthToken=${ACALA_AUTH_TOKEN},moonbeamHistoryApiKey=${MOONBEAM_HISTORY_API_KEY},moonriverHistoryApiKey=${MOONRIVER_HISTORY_API_KEY},etherscanHistoryApiKey=${ETHERSCAN_HISTORY_API_KEY},acalaAuthTestToken=${ACALA_TEST_AUTH_TOKEN},moonbeamApiKey=${MOONBEAM_API_KEY},moonbeamApiTestKey=${MOONBEAM_TEST_API_KEY},infuraApiKey=${INFURA_API_KEY},wcProjectId=${WC_PROJECT_ID},dwellirApiKey=${DWELLIR_API_KEY},polkassemblySummaryApiKey=${POLKASSEMBLY_SUMMARY_API_KEY}