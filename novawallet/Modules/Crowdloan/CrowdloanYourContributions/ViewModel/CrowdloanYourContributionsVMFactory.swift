import Foundation
import UIKit.UIScreen
import SubstrateSdk
import BigInt

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
        externalContributions: [ExternalContribution]?,
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

        let externalContributions = (externalContributions ?? []).compactMap { externalContribution in
            crowdloanExternalContribution(
                externalContribution: externalContribution,
                crowdloans: crowdloans,
                displayInfo: displayInfo,
                chainAsset: chainAsset,
                locale: locale
            )
        }

        return CrowdloanYourContributionsViewModel(contributions: contributions + externalContributions)
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
            let contributed = contributions[model.fundInfo.index]?.balance,
            let contributedText = createContributedText(
                contributed: contributed,
                chainAsset: chainAsset,
                locale: locale
            )
        else { return nil }

        let iconViewModel = createIconViewModel(model: model, displayInfo: displayInfo, chainAsset: chainAsset)

        return CrowdloanContributionViewModel(
            name: title,
            iconViewModel: iconViewModel,
            contributed: contributedText
        )
    }

    private func crowdloanExternalContribution(
        externalContribution: ExternalContribution,
        crowdloans: [Crowdloan],
        displayInfo: CrowdloanDisplayInfoDict?,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloanContributionViewModel? {
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let contributedInParaId = externalContribution.paraId
        let displayInfo = displayInfo?[contributedInParaId]

        guard
            let titlePrefix = displayInfo?.name ?? quantityFormatter.string(from: NSNumber(value: contributedInParaId)),
            let crowdloan = crowdloans.first(where: { $0.paraId == contributedInParaId }),
            let contributedText = createContributedText(
                contributed: externalContribution.amount,
                chainAsset: chainAsset,
                locale: locale
            )
        else { return nil }

        let iconViewModel = createIconViewModel(model: crowdloan, displayInfo: displayInfo, chainAsset: chainAsset)

        let title: String = R.string.localizable.crowdloanCustomContribFormat(
            titlePrefix,
            externalContribution.source ?? "",
            preferredLanguages: locale.rLanguages
        )

        return CrowdloanContributionViewModel(
            name: title,
            iconViewModel: iconViewModel,
            contributed: contributedText
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
        contributed: BigUInt,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> String? {
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(
            for: chainAsset.asset
        ).value(for: locale)

        guard
            let contributionDecimal = Decimal.fromSubstrateAmount(
                contributed,
                precision: chainAsset.asset.assetPrecision
            ),
            let contributed = tokenFormatter.stringFromDecimal(contributionDecimal)
        else {
            return nil
        }

        return contributed
    }
}
