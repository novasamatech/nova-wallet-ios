import Foundation
import UIKit.UIScreen
import SubstrateSdk
import BigInt

final class CrowdloanYourContributionsVMFactory: CrowdloanYourContributionsVMFactoryProtocol {
    let chainDateCalculator: ChainDateCalculatorProtocol
    let calendar: Calendar
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        chainDateCalculator: ChainDateCalculatorProtocol,
        calendar: Calendar,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.chainDateCalculator = chainDateCalculator
        self.calendar = calendar
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }

    func createReturnInIntervals(
        input: CrowdloanYourContributionsViewInput,
        externalContributions: [ExternalContribution]?,
        metadata: CrowdloanMetadata
    ) -> [TimeInterval] {
        let onChainIntervals: [TimeInterval] = input.crowdloans.compactMap { crowdloan in
            guard input.contributions[crowdloan.fundInfo.index]?.balance != nil else {
                return nil
            }

            return chainDateCalculator.intervalTillPeriod(
                crowdloan.fundInfo.lastPeriod + 1,
                metadata: metadata,
                calendar: calendar
            )?.duration
        }

        let crowdloansDict = input.crowdloans.reduce(into: [ParaId: CrowdloanFunds]()) { result, item in
            result[item.paraId] = item.fundInfo
        }

        let externalIntervals: [TimeInterval] = (externalContributions ?? []).compactMap { contribution in
            guard let crowdloanInfo = crowdloansDict[contribution.paraId] else {
                return nil
            }

            return chainDateCalculator.intervalTillPeriod(
                crowdloanInfo.lastPeriod + 1,
                metadata: metadata,
                calendar: calendar
            )?.duration
        }

        return (onChainIntervals + externalIntervals).sorted(by: <)
    }

    func createViewModel(
        input: CrowdloanYourContributionsViewInput,
        externalContributions: [ExternalContribution]?,
        amount: Decimal,
        price: PriceData?,
        locale: Locale
    ) -> CrowdloanYourContributionsViewModel {
        let contributions = input.crowdloans.compactMap { crowdloan in
            crowdloanContribution(
                from: crowdloan,
                input: input,
                chainAsset: input.chainAsset,
                price: price,
                locale: locale
            )
        }

        let externalContributions = (externalContributions ?? []).compactMap { externalContribution in
            crowdloanExternalContribution(
                externalContribution: externalContribution,
                input: input,
                chainAsset: input.chainAsset,
                price: price,
                locale: locale
            )
        }

        let total = createTotalSection(
            chainAsset: input.chainAsset,
            amount: amount,
            priceData: price,
            locale: locale
        )

        let sortedContributions = (contributions + externalContributions)
            .sorted { $0.lastPeriod < $1.lastPeriod }
            .map(\.viewModel)
        let sections: [CrowdloanYourContributionsSection] = [
            .total(total),
            .contributions(sortedContributions)
        ]
        return CrowdloanYourContributionsViewModel(sections: sections)
    }

    private func createTotalSection(
        chainAsset: ChainAssetDisplayInfo,
        amount: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> YourContributionsView.Model {
        let title = R.string.localizable.crowdloanYouContributionsTotal(
            preferredLanguages: locale.rLanguages
        )
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

    private func crowdloanContribution(
        from model: Crowdloan,
        input: CrowdloanYourContributionsViewInput,
        chainAsset: ChainAssetDisplayInfo,
        price: PriceData?,
        locale: Locale
    ) -> LimitedCrowdloanContributionViewModel? {
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let displayInfo = input.displayInfo?[model.paraId]

        guard
            let title = displayInfo?.name ?? quantityFormatter.string(from: NSNumber(value: model.paraId)),
            let contributed = input.contributions[model.fundInfo.index]?.balance
        else { return nil }

        let contributedViewModel = createContributedViewModel(
            contributed: contributed,
            price: price,
            chainAsset: chainAsset,
            locale: locale
        )

        let iconViewModel = createIconViewModel(model: model, displayInfo: displayInfo, chainAsset: chainAsset)

        let viewModel = CrowdloanContributionViewModel(
            name: title,
            iconViewModel: iconViewModel,
            contributed: contributedViewModel
        )
        return .init(viewModel: viewModel, lastPeriod: model.fundInfo.lastPeriod)
    }

    private func crowdloanExternalContribution(
        externalContribution: ExternalContribution,
        input: CrowdloanYourContributionsViewInput,
        chainAsset: ChainAssetDisplayInfo,
        price: PriceData?,
        locale: Locale
    ) -> LimitedCrowdloanContributionViewModel? {
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let contributedInParaId = externalContribution.paraId
        let displayInfo = input.displayInfo?[contributedInParaId]

        guard
            let titlePrefix = displayInfo?.name ?? quantityFormatter.string(from: NSNumber(value: contributedInParaId)),
            let crowdloan = input.crowdloans.first(where: { $0.paraId == contributedInParaId })
        else { return nil }

        let contributedViewModel = createContributedViewModel(
            contributed: externalContribution.amount,
            price: price,
            chainAsset: chainAsset,
            locale: locale
        )

        let iconViewModel = createIconViewModel(model: crowdloan, displayInfo: displayInfo, chainAsset: chainAsset)

        let title: String = R.string.localizable.crowdloanCustomContribFormat(
            titlePrefix,
            externalContribution.source ?? "",
            preferredLanguages: locale.rLanguages
        )

        let viewModel = CrowdloanContributionViewModel(
            name: title,
            iconViewModel: iconViewModel,
            contributed: contributedViewModel
        )
        return .init(viewModel: viewModel, lastPeriod: crowdloan.fundInfo.lastPeriod)
    }

    private func createIconViewModel(
        model: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        chainAsset: ChainAssetDisplayInfo
    ) -> ImageViewModelProtocol? {
        if let urlString = displayInfo?.icon, let url = URL(string: urlString) {
            return RemoteImageViewModel(url: url)
        } else {
            guard
                let depositorAddress = try? model.fundInfo.depositor.toAddress(using: chainAsset.chain),
                let icon = try? iconGenerator.generateFromAddress(depositorAddress).imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.normalAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            else {
                return nil
            }

            return WalletStaticImageViewModel(staticImage: icon)
        }
    }

    private func createContributedViewModel(
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
}

extension CrowdloanYourContributionsVMFactory {
    struct LimitedCrowdloanContributionViewModel {
        let viewModel: CrowdloanContributionViewModel
        let lastPeriod: UInt32
    }
}
