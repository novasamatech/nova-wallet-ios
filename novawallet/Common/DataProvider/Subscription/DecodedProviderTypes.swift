import Foundation
import SubstrateSdk
import BigInt

typealias DecodedBigUInt = ChainStorageDecodedItem<StringScaleMapper<BigUInt>>
typealias DecodedU32 = ChainStorageDecodedItem<StringScaleMapper<UInt32>>
typealias DecodedBytes = ChainStorageDecodedItem<BytesCodable>
typealias DecodedNomination = ChainStorageDecodedItem<Staking.Nomination>
typealias DecodedValidator = ChainStorageDecodedItem<Staking.ValidatorPrefs>
typealias DecodedLedgerInfo = ChainStorageDecodedItem<Staking.Ledger>
typealias DecodedActiveEra = ChainStorageDecodedItem<Staking.ActiveEraInfo>
typealias DecodedEraIndex = ChainStorageDecodedItem<StringScaleMapper<Staking.EraIndex>>
typealias DecodedPayee = ChainStorageDecodedItem<Staking.RewardDestinationArg>
typealias DecodedBlockNumber = ChainStorageDecodedItem<StringScaleMapper<BlockNumber>>
typealias DecodedAccountInfo = ChainStorageDecodedItem<AccountInfo>
typealias DecodedBagListNode = ChainStorageDecodedItem<BagList.Node>
typealias DecodedPoolMember = ChainStorageDecodedItem<NominationPools.PoolMember>
typealias DecodedDelegatedStakingDelegator = ChainStorageDecodedItem<DelegatedStakingPallet.Delegation>
typealias DecodedBondedPool = ChainStorageDecodedItem<NominationPools.BondedPool>
typealias DecodedRewardPool = ChainStorageDecodedItem<NominationPools.RewardPool>
typealias DecodedSubPools = ChainStorageDecodedItem<NominationPools.SubPools>
typealias DecodedPoolId = ChainStorageDecodedItem<StringScaleMapper<NominationPools.PoolId>>
typealias DecodedProxyDefinition = ChainStorageDecodedItem<ProxyDefinition>
typealias DecodedPercent = ChainStorageDecodedItem<StringScaleMapper<Percent>>
