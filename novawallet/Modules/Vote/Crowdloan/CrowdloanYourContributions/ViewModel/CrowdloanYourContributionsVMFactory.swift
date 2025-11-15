import Foundation
import UIKit.UIScreen
import SubstrateSdk
import BigInt

final class CrowdloanYourContributionsVMFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }
}

private extension CrowdloanYourContributionsVMFactory {
    func crowdloanContribution(
        from model: CrowdloanContribution,
        input: CrowdloanYourContributionsViewInput,
        price: PriceData?,
        index: Int,
        locale: Locale
    ) -> LimitedCrowdloanContributionViewModel? {
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let displayInfo = input.displayInfo?[model.paraId]

        guard
            let title = displayInfo?.name ?? quantityFormatter.string(from: NSNumber(value: model.paraId))
        else {
            return nil
        }

        let contributedViewModel = createContributedViewModel(
            contributed: model.amount,
            price: price,
            chainAsset: input.chainAsset,
            locale: locale
        )

        let iconViewModel = createIconViewModel(model: model, displayInfo: displayInfo, chainAsset: input.chainAsset)

        let viewModel = CrowdloanContributionViewModel(
            index: index,
            name: title,
            iconViewModel: iconViewModel,
            contributed: contributedViewModel
        )

        return .init(viewModel: viewModel, unlockAt: model.unlocksAt)
    }

    func createIconViewModel(
        model: CrowdloanContribution,
        displayInfo: CrowdloanDisplayInfo?,
        chainAsset: ChainAssetDisplayInfo
    ) -> ImageViewModelProtocol? {
        if let urlString = displayInfo?.icon, let url = URL(string: urlString) {
            return RemoteImageViewModel(url: url)
        } else {
            // TODO: Need Depositor accountId
            guard
                let depositorAddress = try? model.paraId.serialize32().blake2b32().toAddress(using: chainAsset.chain),
                let icon = try? iconGenerator.generateFromAddress(depositorAddress).imageWithFillColor(
                    R.color.colorIconPrimary()!,
                    size: UIConstants.normalAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            else {
                return nil
            }

            return StaticImageViewModel(image: icon)
        }
    }

    func createContributedViewModel(
        contributed: BigUInt,
        price: PriceData?,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let decimalAmount = Decimal.fromSubstrateAmount(contributed, precision: chainAsset.asset.assetPrecision) ?? 0

        return balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: chainAsset.asset,
            amount: decimalAmount,
            priceData: price
        ).value(for: locale)
    }

    func createTotalSection(
        chainAsset: ChainAssetDisplayInfo,
        amount: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> YourContributionsView.Model {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanYouContributionsTotal()
        let balance = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: chainAsset.asset,
            amount: amount,
            priceData: priceData
        ).value(for: locale)

        let model = YourContributionsView.Model(
            title: title,
            count: nil,
            amount: balance.amount,
            amountDetails: balance.price ?? ""
        )
        return model
    }
}

extension CrowdloanYourContributionsVMFactory: CrowdloanContributionsVMFactoryProtocol {
    func createViewModel(
        input: CrowdloanYourContributionsViewInput,
        price: PriceData?,
        locale: Locale
    ) -> CrowdloanYourContributionsViewModel {
        let contributions = input.contributions.enumerated().compactMap { index, contribution in
            crowdloanContribution(
                from: contribution,
                input: input,
                price: price,
                index: index,
                locale: locale
            )
        }

        let amount = input.contributions.totalAmountLocked().decimal(
            assetInfo: input.chainAsset.asset
        )

        let total = createTotalSection(
            chainAsset: input.chainAsset,
            amount: amount,
            priceData: price,
            locale: locale
        )

        let sortedContributions = contributions
            .sorted { $0.unlockAt < $1.unlockAt }
            .map(\.viewModel)
        let sections: [CrowdloanYourContributionsSection] = [
            .total(total),
            .contributions(sortedContributions)
        ]
        return CrowdloanYourContributionsViewModel(sections: sections)
    }

    func createReturnInIntervals(
        input: CrowdloanYourContributionsViewInput,
        metadata: CrowdloanMetadata
    ) -> [ReturnInIntervalsViewModel] {
        input.contributions
            .enumerated()
            .compactMap { index, contribution in
                let remainedSeconds = BlockTimestampEstimator.estimateTimestamp(
                    for: contribution.unlocksAt,
                    currentBlock: metadata.blockNumber,
                    blockTimeInMillis: metadata.blockDuration
                )

                return ReturnInIntervalsViewModel(index: index, interval: TimeInterval(remainedSeconds))
            }
    }
}

extension CrowdloanYourContributionsVMFactory {
    struct LimitedCrowdloanContributionViewModel {
        let viewModel: CrowdloanContributionViewModel
        let unlockAt: BlockNumber
    }
}
