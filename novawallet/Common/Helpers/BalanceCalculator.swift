import Foundation
import RobinHood
import BigInt

protocol BalancesCalculating: AnyObject {
    func calculateTotalValue(for wallet: MetaAccountModel) -> Decimal
}

final class BalancesCalculator {
    private var identifierMapping: [String: AssetBalanceId] = [:]
    private var balances: [AccountId: [ChainAssetId: BigUInt]] = [:]
    private var crowdloanContributions: [AccountId: [ChainModel.Id: BigUInt]] = [:]
    private var crowdloanContributionsMapping: [String: CrowdloanContributionId] = [:]
    private var prices: [ChainAssetId: PriceData] = [:]
    private var chains: [ChainModel.Id: ChainModel] = [:]

    func didReceiveBalancesChanges(_ changes: [DataProviderChange<AssetBalance>]) {
        for change in changes {
            switch change {
            case let .insert(item), let .update(item):
                var accountBalance = balances[item.accountId] ?? [:]
                accountBalance[item.chainAssetId] = item.totalInPlank
                balances[item.accountId] = accountBalance

                identifierMapping[item.identifier] = AssetBalanceId(
                    chainId: item.chainAssetId.chainId,
                    assetId: item.chainAssetId.assetId,
                    accountId: item.accountId
                )
            case let .delete(deletedIdentifier):
                if let accountBalanceId = identifierMapping[deletedIdentifier] {
                    var accountBalance = balances[accountBalanceId.accountId]
                    accountBalance?[accountBalanceId.chainAssetId] = nil
                    balances[accountBalanceId.accountId] = accountBalance
                }

                identifierMapping[deletedIdentifier] = nil
            }
        }
    }

    func didReceiveChainChanges(_ changes: [DataProviderChange<ChainModel>]) {
        chains = changes.mergeToDict(chains)
    }

    func didReceivePrice(_ changes: [ChainAssetId: DataProviderChange<PriceData>]) {
        prices = changes.reduce(into: prices) { accum, keyValue in
            accum[keyValue.key] = keyValue.value.item
        }
    }

    func didReceiveCrowdloanContributionChanges(_ changes: [DataProviderChange<CrowdloanContributionData>]) {
        for change in changes {
            switch change {
            case let .insert(item), let .update(item):
                let previousAmount = crowdloanContributionsMapping[item.identifier]?.amount ?? 0
                var accountCrowdloan = crowdloanContributions[item.accountId] ?? [:]
                let value: BigUInt = accountCrowdloan[item.chainId] ?? 0
                accountCrowdloan[item.chainId] = value - previousAmount + item.amount
                crowdloanContributions[item.accountId] = accountCrowdloan
                crowdloanContributionsMapping[item.identifier] = CrowdloanContributionId(
                    chainId: item.chainId,
                    accountId: item.accountId,
                    amount: item.amount
                )
            case let .delete(deletedIdentifier):
                if let accountContributionId = crowdloanContributionsMapping[deletedIdentifier] {
                    var accountContributions = crowdloanContributions[accountContributionId.accountId]
                    if let contribution = accountContributions?[accountContributionId.chainId],
                       contribution > accountContributionId.amount {
                        let newAmount = contribution - accountContributionId.amount
                        accountContributions?[accountContributionId.chainId] = newAmount
                    } else {
                        accountContributions?[accountContributionId.chainId] = nil
                    }
                    crowdloanContributions[accountContributionId.accountId] = accountContributions
                }

                crowdloanContributionsMapping[deletedIdentifier] = nil
            }
        }
    }

    func calculateValue(
        chains: [ChainModel.Id: ChainModel],
        balances: [ChainAssetId: BigUInt],
        prices: [ChainAssetId: PriceData],
        includingChainIds: Set<ChainModel.Id>,
        excludingChainIds: Set<ChainModel.Id>
    ) -> Decimal {
        balances.reduce(Decimal.zero) { amount, chainAssetBalance in
            let includingChain = includingChainIds.isEmpty || includingChainIds.contains(chainAssetBalance.key.chainId)
            let excludingChain = excludingChainIds.contains(chainAssetBalance.key.chainId)

            guard
                includingChain, !excludingChain,
                let priceData = prices[chainAssetBalance.key],
                let price = Decimal(string: priceData.price),
                let asset = chains[chainAssetBalance.key.chainId]?.asset(for: chainAssetBalance.key.assetId),
                let decimalBalance = Decimal.fromSubstrateAmount(
                    chainAssetBalance.value,
                    precision: Int16(bitPattern: asset.precision)
                ) else {
                return amount
            }

            return amount + decimalBalance * price
        }
    }

    private func calculateCrowdloanContribution(
        _ contributions: [ChainModel.Id: BigUInt],
        chains: [ChainModel.Id: ChainModel],
        prices: [ChainAssetId: PriceData]
    ) -> Decimal {
        contributions.reduce(0) { result, contribution in
            guard let asset = chains[contribution.key]?.utilityAsset(),
                  let priceData = prices[ChainAssetId(chainId: contribution.key, assetId: asset.assetId)],
                  let price = Decimal(string: priceData.price) else {
                return result
            }
            guard let decimalAmount = Decimal.fromSubstrateAmount(
                contribution.value,
                precision: Int16(bitPattern: asset.precision)
            ) else {
                return result
            }

            return result + decimalAmount * price
        }
    }

    func calculateTotalValue(for accountId: AccountId, excludingChainIds: Set<ChainModel.Id>) -> Decimal {
        let balances = calculateValue(
            chains: chains,
            balances: balances[accountId] ?? [:],
            prices: prices,
            includingChainIds: Set(),
            excludingChainIds: excludingChainIds
        )

        let contributions = crowdloanContributions[accountId]?
            .filter { !excludingChainIds.contains($0.key) } ?? [:]

        let crowdloans = calculateCrowdloanContribution(
            contributions,
            chains: chains,
            prices: prices
        )

        return balances + crowdloans
    }
}

extension BalancesCalculator: BalancesCalculating {
    func calculateTotalValue(for wallet: MetaAccountModel) -> Decimal {
        let chainAccountIds = wallet.chainAccounts.map(\.chainId)

        var totalValue: Decimal = 0.0

        if let substrateAccountId = wallet.substrateAccountId {
            totalValue += calculateTotalValue(
                for: substrateAccountId,
                excludingChainIds: Set(chainAccountIds)
            )
        }

        if let ethereumAddress = wallet.ethereumAddress {
            totalValue += calculateTotalValue(
                for: ethereumAddress,
                excludingChainIds: Set(chainAccountIds)
            )
        }

        wallet.chainAccounts.forEach { chainAccount in
            totalValue += calculateValue(
                chains: chains,
                balances: balances[chainAccount.accountId] ?? [:],
                prices: prices,
                includingChainIds: [chainAccount.chainId],
                excludingChainIds: Set()
            )
            let contributions = crowdloanContributions[chainAccount.accountId] ?? [:]
            totalValue += calculateCrowdloanContribution(
                contributions,
                chains: chains,
                prices: prices
            )
        }

        return totalValue
    }
}
