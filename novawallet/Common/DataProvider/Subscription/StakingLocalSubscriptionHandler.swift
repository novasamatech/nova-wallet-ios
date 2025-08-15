import Foundation
import BigInt

protocol StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for address: AccountAddress)

    func handleNomination(
        result: Result<Staking.Nomination?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleValidator(
        result: Result<Staking.ValidatorPrefs?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleLedgerInfo(
        result: Result<Staking.Ledger?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleBagListNode(
        result: Result<BagList.Node?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handlePayee(
        result: Result<Staking.RewardDestinationArg?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId: ChainModel.Id)

    func handleTotalIssuance(result: Result<BigUInt?, Error>, chainId: ChainModel.Id)

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId: ChainModel.Id)

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId: ChainModel.Id)

    func handleBagListSize(result: Result<UInt32?, Error>, chainId: ChainModel.Id)

    func handleActiveEra(result: Result<Staking.ActiveEraInfo?, Error>, chainId: ChainModel.Id)

    func handleCurrentEra(result: Result<Staking.EraIndex?, Error>, chainId: ChainModel.Id)
}

extension StakingLocalSubscriptionHandler {
    func handleStashItem(result _: Result<StashItem?, Error>, for _: AccountAddress) {}

    func handleNomination(
        result _: Result<Staking.Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleValidator(
        result _: Result<Staking.ValidatorPrefs?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleLedgerInfo(
        result _: Result<Staking.Ledger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleBagListNode(
        result _: Result<BagList.Node?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handlePayee(
        result _: Result<Staking.RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}

    func handleTotalIssuance(result _: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {}

    func handleMinNominatorBond(result _: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {}

    func handleCounterForNominators(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleMaxNominatorsCount(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleBagListSize(result _: Result<UInt32?, Error>, chainId _: ChainModel.Id) {}

    func handleActiveEra(result _: Result<Staking.ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {}

    func handleCurrentEra(result _: Result<Staking.EraIndex?, Error>, chainId _: ChainModel.Id) {}
}
