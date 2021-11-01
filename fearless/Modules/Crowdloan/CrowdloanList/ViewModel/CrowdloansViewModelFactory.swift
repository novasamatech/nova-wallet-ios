import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils
import BigInt

protocol CrowdloansViewModelFactoryProtocol {
    func createChainViewModel(
        from chain: ChainModel,
        asset: AssetModel,
        balance: BigUInt?,
        locale: Locale
    ) -> CrowdloansChainViewModel

    func createViewModel(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloansViewModel
}

final class CrowdloansViewModelFactory {
    struct CommonContent {
        let title: String
        let details: CrowdloanDescViewModel
        let progressText: String
        let progressPercentsText: String
        let progressValue: Double
        let imageViewModel: ImageViewModelProtocol
        let contribution: String?
    }

    struct Formatters {
        let token: TokenFormatter
        let quantity: NumberFormatter
        let display: LocalizableDecimalFormatting
        let time: TimeFormatterProtocol
    }

    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    private lazy var dateFormatter = {
        CompoundDateFormatterBuilder()
    }()

    init(
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.amountFormatterFactory = amountFormatterFactory
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

        let (progressText, progressValue, percentsText): (String, Double, String) = {
            if
                let raised = Decimal.fromSubstrateAmount(
                    model.fundInfo.raised,
                    precision: chainAsset.asset.assetPrecision
                ),
                let cap = Decimal.fromSubstrateAmount(
                    model.fundInfo.cap,
                    precision: chainAsset.asset.assetPrecision
                ),
                let raisedString = formatters.display.stringFromDecimal(raised),
                let totalString = formatters.token.stringFromDecimal(cap) {
                let text = R.string.localizable.crowdloanProgressFormat(
                    raisedString,
                    totalString,
                    preferredLanguages: locale.rLanguages
                )
                let value = Double(truncating: raised as NSNumber) / Double(truncating: cap as NSNumber)
                let percents = String(format: "%.2f%%", value * 100.0)
                return (text, value, percents)
            } else {
                return ("", 0.0, "")
            }
        }()

        let iconViewModel: ImageViewModelProtocol = {
            if let urlString = displayInfo?.icon, let url = URL(string: urlString) {
                return RemoteImageViewModel(url: url)
            } else {
                let icon = try? iconGenerator.generateFromAddress(depositorAddress).imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.normalAddressIconSize,
                    contentScale: UIScreen.main.scale
                )

                return WalletStaticImageViewModel(staticImage: icon ?? UIImage())
            }

        }()

        let contributionString: String? = {
            if
                let contributionInPlank = viewInfo.contributions[model.fundInfo.trieIndex]?.balance,
                let contributionDecimal = Decimal.fromSubstrateAmount(
                    contributionInPlank,
                    precision: chainAsset.asset.assetPrecision
                ) {
                return formatters.token.stringFromDecimal(contributionDecimal).map { value in
                    R.string.localizable.crowdloanContributionFormat(value, preferredLanguages: locale.rLanguages)
                }
            } else {
                return nil
            }
        }()

        return CommonContent(
            title: title ?? "",
            details: details,
            progressText: progressText,
            progressPercentsText: percentsText,
            progressValue: progressValue,
            imageViewModel: iconViewModel,
            contribution: contributionString
        )
    }

    private func crowdloanCotribution(
        from model: Crowdloan,
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        formatters: Formatters,
        locale: Locale
    ) -> CrowdloanContributionItem? {
        let displayInfo = viewInfo.displayInfo?[model.paraId]

        guard let depositorAddress = try? model.fundInfo.depositor.toAddress(using: chainAsset.chain) else {
            return nil
        }

        guard
            let title = displayInfo?.name ?? formatters.quantity.string(from: NSNumber(value: model.paraId))
        else { return nil }

        let iconViewModel: ImageViewModelProtocol? = {
            if let urlString = displayInfo?.icon, let url = URL(string: urlString) {
                return RemoteImageViewModel(url: url)
            } else {
                guard let icon = try? iconGenerator.generateFromAddress(depositorAddress).imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.normalAddressIconSize,
                    contentScale: UIScreen.main.scale
                ) else {
                    return nil
                }

                return WalletStaticImageViewModel(staticImage: icon)
            }
        }()

        guard
            let contributionInPlank = viewInfo.contributions[model.fundInfo.trieIndex]?.balance,
            let contributionDecimal = Decimal.fromSubstrateAmount(
                contributionInPlank,
                precision: chainAsset.asset.assetPrecision
            ),
            let contributed = formatters.token.stringFromDecimal(contributionDecimal).map({ value in
                R.string.localizable.crowdloanContributionFormat(value, preferredLanguages: locale.rLanguages)
            })
        else {
            return nil
        }

        return CrowdloanContributionItem(
            name: title,
            iconViewModel: iconViewModel,
            contributed: contributed
        )
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
                return R.string.localizable.commonDaysFormat(
                    format: remainedTime.daysFromSeconds,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                let time = try? formatters.time.string(from: remainedTime)
                return R.string.localizable.commonTimeLeftFormat(
                    time ?? "",
                    preferredLanguages: locale.rLanguages
                )
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
            contribution: commonContent.contribution
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

        return CrowdloanCellViewModel(
            paraId: model.paraId,
            title: commonContent.title,
            timeleft: nil,
            description: commonContent.details,
            progress: commonContent.progressText,
            iconViewModel: commonContent.imageViewModel,
            progressPercentsText: "100%",
            progressValue: 1.0,
            contribution: commonContent.contribution
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
            [CrowdloanCellViewModel](),
            [CrowdloanCellViewModel]()
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
                    result.1.append(viewModel)
                }
            } else {
                if let viewModel = createActiveCrowdloanViewModel(
                    from: crowdloan,
                    viewInfo: viewInfo,
                    chainAsset: chainAsset,
                    formatters: formatters,
                    locale: locale
                ) {
                    result.0.append(viewModel)
                }
            }
        }

        let (active, completed) = cellsViewModel
        let activeTitle = R.string.localizable
            .crowdloanActiveSection(preferredLanguages: locale.rLanguages)
        let completedTitle = R.string.localizable
            .crowdloanCompletedSection(preferredLanguages: locale.rLanguages)

        if !active.isEmpty {
            if !completed.isEmpty {
                return [.active(activeTitle, active), .completed(completedTitle, completed)]
            } else {
                return [.active(activeTitle, active)]
            }
        } else {
            if !completed.isEmpty {
                return [.completed(completedTitle, completed)]
            } else {
                return []
            }
        }
    }
}

extension CrowdloansViewModelFactory: CrowdloansViewModelFactoryProtocol {
    func createChainViewModel(
        from chain: ChainModel,
        asset: AssetModel,
        balance: BigUInt?,
        locale: Locale
    ) -> CrowdloansChainViewModel {
        let displayInfo = asset.displayInfo

        let amountFormatter = amountFormatterFactory.createTokenFormatter(
            for: asset.displayInfo
        ).value(for: locale)

        let amount: String

        if
            let balance = balance,
            let decimalAmount = Decimal.fromSubstrateAmount(
                balance,
                precision: displayInfo.assetPrecision
            ) {
            amount = amountFormatter.stringFromDecimal(decimalAmount) ?? ""
        } else {
            amount = ""
        }

        let imageViewModel = RemoteImageViewModel(url: chain.icon)

        let description = R.string.localizable.crowdloanListSectionFormat(
            displayInfo.symbol,
            preferredLanguages: locale.rLanguages
        )

        return CrowdloansChainViewModel(
            networkName: chain.name,
            balance: amount,
            imageViewModel: imageViewModel,
            title: R.string.localizable.crowdloanAboutCrowdloans(preferredLanguages: locale.rLanguages),
            description: description
        )
    }

    func createViewModel(
        from crowdloans: [Crowdloan],
        viewInfo: CrowdloansViewInfo,
        chainAsset: ChainAssetDisplayInfo,
        locale: Locale
    ) -> CrowdloansViewModel {
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

        let contributions = crowdloans.compactMap { crowdloan in
            crowdloanCotribution(
                from: crowdloan,
                viewInfo: viewInfo,
                chainAsset: chainAsset,
                formatters: formatters,
                locale: locale
            )
        }

        let contributionsTitle = R.string.localizable.crowdloanYouContributionsTitle(
            preferredLanguages: locale.rLanguages
        )

        let sections: [CrowdloansSection] =
            (!contributions.isEmpty ?
                [.yourContributions(contributionsTitle, contributions)]
                : [])
            + crowdloansSections

        return CrowdloansViewModel(
            sections: sections
        )
    }
}
