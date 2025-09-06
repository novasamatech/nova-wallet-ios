#!/usr/bin/env bash

WORK_DIR="novawallet"

echo "Sourcery Work Directory = $WORK_DIR"

#check if env-vars.sh exists
if [ -f $WORK_DIR/env-vars.sh ]
then
source $WORK_DIR/env-vars.sh
fi
#no `else` case needed if the CI works as expected

OUT_FILE="$WORK_DIR/CIKeys.generated.swift"
echo "Sourcery Output File = $OUT_FILE"

mint run krzysztofzablocki/Sourcery@1.4.1 sourcery \
 --templates $WORK_DIR \
 --sources $WORK_DIR \
 --output $OUT_FILE \
 --args mercuryoSecretKey=${MERCURYO_PRODUCTION_SECRET},mercuryoTestSecretKey=${MERCURYO_TEST_SECRET},acalaAuthToken=${ACALA_AUTH_TOKEN},moonbeamHistoryApiKey=${MOONBEAM_HISTORY_API_KEY},moonriverHistoryApiKey=${MOONRIVER_HISTORY_API_KEY},etherscanHistoryApiKey=${ETHERSCAN_HISTORY_API_KEY},acalaAuthTestToken=${ACALA_TEST_AUTH_TOKEN},moonbeamApiKey=${MOONBEAM_API_KEY},moonbeamApiTestKey=${MOONBEAM_TEST_API_KEY},infuraApiKey=${INFURA_API_KEY},wcProjectId=${WC_PROJECT_ID},dwellirApiKey=${DWELLIR_API_KEY},polkassemblySummaryApiKey=${POLKASSEMBLY_SUMMARY_API_KEY}