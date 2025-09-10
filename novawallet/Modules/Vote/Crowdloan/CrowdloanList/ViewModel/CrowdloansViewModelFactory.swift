import Foundation
import UIKit
import Foundation_iOS
import SubstrateSdk
import BigInt

protocol CrowdloansViewModelFactoryProtocol {
    func createViewModel(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        externalContributionsCount: Int,
        amount: Decimal?,
        priceData: PriceData?,
        locale: Locale
    ) -> CrowdloansViewModel

    func createErrorViewModel(
        chainAsset: ChainAssetDisplayInfo?,
        locale: Locale
    ) -> CrowdloansViewModel

    func createLoadingViewModel() -> CrowdloansViewModel
}

final class CrowdloansViewModelFactory {
    struct CommonContent {
        let title: String
        let details: CrowdloanDescViewModel
        let progressText: String
        let progressPercentsText: String
        let progressValue: Double
        let imageViewModel: ImageViewModelProtocol
    }

    struct Formatters {
        let token: TokenFormatter
        let quantity: NumberFormatter
        let display: LocalizableDecimalFormatting
        let time: TimeFormatterProtocol
    }

    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var percentFormatter = NumberFormatter.percent
    private lazy var dateFormatter = {
        CompoundDateFormatterBuilder()
    }()

    init(
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.amountFormatterFactory = amountFormatterFactory
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }

    private func createCommonContent(
        from model: Crowdloan,
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> CommonContent? {
        let displayInfo = viewInfo.displayInfo?[model.paraId]

        guard let depositorAddress = try? model.fundInfo.depositor.toAddress(using: chainAsset.chain) else {
            return nil
        }

        let title = displayInfo?.name ?? formatters.quantity.string(from: NSNumber(value: model.paraId))
        let details: CrowdloanDescViewModel = {
            if let desc = displayInfo?.description {
                return .text(desc)
            } else {
                return .address(depositorAddress)
            }
        }()

        let (progressText, progressValue, percentsText) = progressValueAndText(
            fundInfo: model.fundInfo,
            precision: chainAsset.asset.assetPrecision,
            formatters: formatters,
            locale: locale
        )

        let iconViewModel: ImageViewModelProtocol = {
            if let urlString = displayInfo?.icon, let url = URL(string: urlString) {
                return RemoteImageViewModel(url: url)
            } else {
                let icon = try? iconGenerator.generateFromAddress(depositorAddress).imageWithFillColor(
                    R.color.colorTextPrimary()!,
                    size: UIConstants.normalAddressIconSize,
                    contentScale: UIScreen.main.scale
                )

                return StaticImageViewModel(image: icon ?? UIImage())
            }
        }()

        return CommonContent(
            title: title ?? "",
            details: details,
            progressText: progressText,
            progressPercentsText: percentsText,
            progressValue: progressValue,
            imageViewModel: iconViewModel
        )
    }

    private func hasContribution(
        in crowdloan: Crowdloan,
        viewInfo: CrowdloansViewInfo
    ) -> Bool {
        viewInfo.contributions[crowdloan.fundInfo.index]?.balance != nil
    }

    private func progressValueAndText(
        fundInfo: CrowdloanFunds,
        precision: Int16,
        formatters: Formatters,
        locale: Locale
    ) -> (String, Double, String) {
        if
            let raised = Decimal.fromSubstrateAmount(
                fundInfo.raised,
                precision: precision
            ),
            let cap = Decimal.fromSubstrateAmount(
                fundInfo.cap,
                precision: precision
            ),
            let raisedString = formatters.display.stringFromDecimal(raised),
            let totalString = formatters.token.stringFromDecimal(cap) {
            let text = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanProgressFormat(raisedString, totalString)
            let value: Double = {
                guard cap != 0 else { return 0 }
                return Double(truncating: raised as NSNumber) / Double(truncating: cap as NSNumber)
            }()

            let percents = percentFormatter.string(from: NSNumber(value: value)) ?? ""
            return (text, value, percents)
        } else {
            return ("", 0.0, "")
        }
    }

    private func createActiveCrowdloanViewModel(
        from model: Crowdloan,
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> CrowdloanCellViewModel? {
        guard let commonContent = createCommonContent(
            from: model,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            formatters: formatters,
            locale: locale
        ) else {
            return nil
        }

        let timeLeft: String = {
            let remainedTime = model.remainedTime(
                at: viewInfo.metadata.blockNumber,
                blockDuration: viewInfo.metadata.blockDuration
            )

            if remainedTime.daysFromSeconds > 0 {
                return R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysFormat(format: remainedTime.daysFromSeconds)
            } else {
                let time = try? formatters.time.string(from: remainedTime)
                return R.string(preferredLanguages: locale.rLanguages).localizable.commonTimeLeftFormat(time ?? "")
            }
        }()

        return CrowdloanCellViewModel(
            paraId: model.paraId,
            title: commonContent.title,
            timeleft: timeLeft,
            description: commonContent.details,
            progress: commonContent.progressText,
            iconViewModel: commonContent.imageViewModel,
            progressPercentsText: commonContent.progressPercentsText,
            progressValue: commonContent.progressValue,
            isCompleted: false
        )
    }

    private func createCompletedCrowdloanViewModel(
        from model: Crowdloan,
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> CrowdloanCellViewModel? {
        guard let commonContent = createCommonContent(
            from: model,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            formatters: formatters,
            locale: locale
        ) else {
            return nil
        }

        let (_, progressValue, percentsText) = progressValueAndText(
            fundInfo: model.fundInfo,
            precision: chainAsset.asset.assetPrecision,
            formatters: formatters,
            locale: locale
        )

        return CrowdloanCellViewModel(
            paraId: model.paraId,
            title: commonContent.title,
            timeleft: nil,
            description: commonContent.details,
            progress: commonContent.progressText,
            iconViewModel: commonContent.imageViewModel,
            progressPercentsText: percentsText,
            progressValue: progressValue,
            isCompleted: true
        )
    }

    func createSections(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> [CrowdloansSection] {
        let initial = (
            [LoadableViewModelState<CrowdloanCellViewModel>](),
            [LoadableViewModelState<CrowdloanCellViewModel>]()
        )

        let cellsViewModel = crowdloans.sorted { crowdloan1, crowdloan2 in
            if crowdloan1.fundInfo.raised != crowdloan2.fundInfo.raised {
                return crowdloan1.fundInfo.raised > crowdloan2.fundInfo.raised
            } else {
                return crowdloan1.fundInfo.end < crowdloan2.fundInfo.end
            }
        }.reduce(into: initial) { result, crowdloan in
            let hasWonAuction = viewInfo.leaseInfo[crowdloan.paraId]?.leasedAmount != nil
            if hasWonAuction || crowdloan.isCompleted(for: viewInfo.metadata) {
                if let viewModel = createCompletedCrowdloanViewModel(
                    from: crowdloan,
                    viewInfo: viewInfo,
                    chainAsset: chainAsset,
                    formatters: formatters,
                    locale: locale
                ) {
                    result.1.append(.loaded(value: viewModel))
                }
            } else {
                if let viewModel = createActiveCrowdloanViewModel(
                    from: crowdloan,
                    viewInfo: viewInfo,
                    chainAsset: chainAsset,
                    formatters: formatters,
                    locale: locale
                ) {
                    result.0.append(.loaded(value: viewModel))
                }
            }
        }

        let (active, completed) = cellsViewModel
        let activeTitle = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanActiveSection()
        let completedTitle = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanCompletedSection()

        if !active.isEmpty {
            if !completed.isEmpty {
                return [
                    .active(.loaded(value: activeTitle), active),
                    .completed(.loaded(value: completedTitle), completed)
                ]
            } else {
                return [.active(.loaded(value: activeTitle), active)]
            }
        } else {
            if !completed.isEmpty {
                return [.completed(.loaded(value: completedTitle), completed)]
            } else {
                return []
            }
        }
    }
}

extension CrowdloansViewModelFactory: CrowdloansViewModelFactoryProtocol {
    func createErrorViewModel(
        chainAsset: ChainAssetDisplayInfo?,
        locale: Locale
    ) -> CrowdloansViewModel {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorNoDataRetrieved_v3_9_1()
        let errorSection = CrowdloansSection.error(message: message)
        let aboutSection = createAboutSection(chainAsset: chainAsset, locale: locale)
        return .init(sections: [
            aboutSection,
            errorSection
        ])
    }

    func createViewModel(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        externalContributionsCount: Int,
        amount: Decimal?,
        priceData: PriceData?,
        locale: Locale
    ) -> CrowdloansViewModel {
        guard !crowdloans.isEmpty else {
            let aboutSection = createAboutSection(chainAsset: chainAsset, locale: locale)
            let activeTitle = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanActiveSection()
            let emptySection = CrowdloansSection.empty(title: activeTitle)

            return .init(sections: [
                aboutSection,
                emptySection
            ])
        }

        let timeFormatter = TotalTimeFormatter()
        let quantityFormatter = NumberFormatter.quantity.localizableResource().value(for: locale)
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(
            for: chainAsset.asset
        ).value(for: locale)

        let displayFormatter = amountFormatterFactory.createDisplayFormatter(
            for: chainAsset.asset
        ).value(for: locale)

        let formatters = Formatters(
            token: tokenFormatter,
            quantity: quantityFormatter,
            display: displayFormatter,
            time: timeFormatter
        )

        let crowdloansSections = createSections(
            from: crowdloans,
            viewInfo: viewInfo,
            chainAsset: chainAsset,
            formatters: formatters,
            locale: locale
        )

        let contributions = crowdloans
            .compactMap { hasContribution(in: $0, viewInfo: viewInfo) }
            .filter { $0 }
        let allContributionsCount = contributions.count + externalContributionsCount

        guard let amount = amount else {
            return .init(sections: crowdloansSections)
        }

        let contributionSection = amount > 0 ? createYourContributionsSection(
            chainAsset: chainAsset,
            contributions: allContributionsCount,
            amount: amount,
            priceData: priceData,
            locale: locale
        ) : createAboutSection(chainAsset: chainAsset, locale: locale)

        return .init(sections: [contributionSection] + crowdloansSections)
    }

    func createLoadingViewModel() -> CrowdloansViewModel {
        CrowdloansViewModel(sections: [
            CrowdloansSection.yourContributions(.loading),
            CrowdloansSection.active(.loading, Array(repeating: .loading, count: 10))
        ])
    }

    private func createAboutSection(chainAsset: ChainAssetDisplayInfo?, locale: Locale) -> CrowdloansSection {
        let symbol = chainAsset?.asset.symbol ?? ""
        let description = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanListSectionFormat_v2_2_0(symbol)

        let model = AboutCrowdloansView.Model(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanAboutCrowdloans(),
            subtitle: description
        )
        return .about(model)
    }

    private func createYourContributionsSection(
        chainAsset: ChainAssetDisplayInfo,
        contributions: Int,
        amount: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> CrowdloansSection {
        let contributionsTitle = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanYouContributionsTitle()
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
