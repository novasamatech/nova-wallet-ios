import Foundation
import SubstrateSdk
import BigInt

typealias DecodedBigUInt = ChainStorageDecodedItem<StringScaleMapper<BigUInt>>
typealias DecodedU32 = ChainStorageDecodedItem<StringScaleMapper<UInt32>>
typealias DecodedBytes = ChainStorageDecodedItem<BytesCodable>
typealias DecodedNomination = ChainStorageDecodedItem<Nomination>
typealias DecodedValidator = ChainStorageDecodedItem<ValidatorPrefs>
typealias DecodedLedgerInfo = ChainStorageDecodedItem<StakingLedger>
typealias DecodedActiveEra = ChainStorageDecodedItem<ActiveEraInfo>
typealias DecodedEraIndex = ChainStorageDecodedItem<StringScaleMapper<EraIndex>>
typealias DecodedPayee = ChainStorageDecodedItem<Staking.RewardDestinationArg>
typealias DecodedBlockNumber = ChainStorageDecodedItem<StringScaleMapper<BlockNumber>>
typealias DecodedCrowdloanFunds = ChainStorageDecodedItem<CrowdloanFunds>
typealias DecodedBagListNode = ChainStorageDecodedItem<BagList.Node>
typealias DecodedPoolMember = ChainStorageDecodedItem<NominationPools.PoolMember>
typealias DecodedBondedPool = ChainStorageDecodedItem<NominationPools.BondedPool>
typealias DecodedRewardPool = ChainStorageDecodedItem<NominationPools.RewardPool>
typealias DecodedSubPools = ChainStorageDecodedItem<NominationPools.SubPools>
typealias DecodedPoolId = ChainStorageDecodedItem<NominationPools.PoolId>
