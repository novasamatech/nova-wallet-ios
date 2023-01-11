import Foundation
import SubstrateSdk
import BigInt

typealias DecodedBigUInt = ChainStorageDecodedItem<StringScaleMapper<BigUInt>>
typealias DecodedU32 = ChainStorageDecodedItem<StringScaleMapper<UInt32>>
typealias DecodedNomination = ChainStorageDecodedItem<Nomination>
typealias DecodedValidator = ChainStorageDecodedItem<ValidatorPrefs>
typealias DecodedLedgerInfo = ChainStorageDecodedItem<StakingLedger>
typealias DecodedActiveEra = ChainStorageDecodedItem<ActiveEraInfo>
typealias DecodedEraIndex = ChainStorageDecodedItem<StringScaleMapper<EraIndex>>
typealias DecodedPayee = ChainStorageDecodedItem<RewardDestinationArg>
typealias DecodedBlockNumber = ChainStorageDecodedItem<StringScaleMapper<BlockNumber>>
typealias DecodedCrowdloanFunds = ChainStorageDecodedItem<CrowdloanFunds>
