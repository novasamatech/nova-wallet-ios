import Foundation
import UIKit
import Foundation_iOS
import SubstrateSdk
import BigInt

protocol CrowdloansViewModelFactoryProtocol {
    func createViewModel(
        from viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> CrowdloansViewModel

    func createLoadingViewModel() -> CrowdloansViewModel
}

final class CrowdloansViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }
}

private extension CrowdloansViewModelFactory {
    func createYourContributionsSection(
        chainAsset: ChainAssetDisplayInfo,
        contributions: Int,
        amount: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> CrowdloansSection {
        let contributionsTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanYouContributionsTitle()
        let balance = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: chainAsset.asset,
            amount: amount,
            priceData: priceData
        ).value(for: locale)

        let model = YourContributionsView.Model(
            title: contributionsTitle,
            count: "\(contributions)",
            amount: balance.amount,
            amountDetails: balance.price ?? ""
        )
        return .yourContributions(.loaded(value: model))
    }
}

extension CrowdloansViewModelFactory: CrowdloansViewModelFactoryProtocol {
    func createViewModel(
        from viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> CrowdloansViewModel {
        let active = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanActiveSection()
        let crowdloansSections: [CrowdloansSection] = [.empty(title: active)]

        let allContributionsCount = viewInfo.contributions.count
        let totalAmount = viewInfo.contributions.totalAmountLocked()

        guard totalAmount > 0 else {
            return .init(sections: crowdloansSections)
        }

        let amountDecimal = totalAmount.decimal(assetInfo: chainAsset.asset)

        let contributionSection = createYourContributionsSection(
            chainAsset: chainAsset,
            contributions: allContributionsCount,
            amount: amountDecimal,
            priceData: priceData,
            locale: locale
        )

        return .init(sections: [contributionSection] + crowdloansSections)
    }

    func createLoadingViewModel() -> CrowdloansViewModel {
        CrowdloansViewModel(sections: [
            CrowdloansSection.yourContributions(.loading),
            CrowdloansSection.active(.loading, Array(repeating: .loading, count: 10))
        ])
    }
}
