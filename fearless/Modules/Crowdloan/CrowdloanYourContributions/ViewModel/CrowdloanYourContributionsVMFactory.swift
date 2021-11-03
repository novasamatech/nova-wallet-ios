import Foundation
import UIKit.UIScreen
import FearlessUtils

final class CrowdloanYourContributionsVMFactory: CrowdloanYourContributionsVMFactoryProtocol {
    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.amountFormatterFactory = amountFormatterFactory
    }

    func createViewModel(
        for crowdloans: [Crowdloan],
        contributions: CrowdloanContributionDict,
        displayInfo: CrowdloanDisplayInfoDict?,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloanYourContributionsViewModel {
        let contributions = crowdloans.compactMap { crowdloan in
            crowdloanCotribution(
                from: crowdloan,
                contributions: contributions,
                displayInfo: displayInfo,
                chainAsset: chainAsset,
                locale: locale
            )
        }

        return CrowdloanYourContributionsViewModel(contributions: contributions)
    }

    private func crowdloanCotribution(
        from model: Crowdloan,
        contributions: CrowdloanContributionDict,
        displayInfo: CrowdloanDisplayInfoDict?,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloanContributionViewModel? {
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let displayInfo = displayInfo?[model.paraId]

        guard
            let title = displayInfo?.name ?? quantityFormatter.string(from: NSNumber(value: model.paraId)),
            let contributed = createContributedText(
                model: model,
                contributions: contributions,
                chainAsset: chainAsset,
                locale: locale
            )
        else { return nil }

        let iconViewModel = createIconViewModel(model: model, displayInfo: displayInfo, chainAsset: chainAsset)

        return CrowdloanContributionViewModel(
            name: title,
            iconViewModel: iconViewModel,
            contributed: contributed
        )
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

    private func createContributedText(
        model: Crowdloan,
        contributions: CrowdloanContributionDict,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> String? {
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(
            for: chainAsset.asset
        ).value(for: locale)

        guard
            let contributionInPlank = contributions[model.fundInfo.trieIndex]?.balance,
            let contributionDecimal = Decimal.fromSubstrateAmount(
                contributionInPlank,
                precision: chainAsset.asset.assetPrecision
            ),
            let contributed = tokenFormatter.stringFromDecimal(contributionDecimal)
        else {
            return nil
        }

        return contributed
    }
}
