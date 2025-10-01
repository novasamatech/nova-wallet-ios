import Foundation
import UIKit
import BigInt

protocol AHMInfoViewModelFactoryProtocol {
    func createViewModel(
        from info: AHMRemoteData,
        sourceChain: ChainModel,
        destinationChain: ChainModel,
        bannerState: BannersState,
        locale: Locale
    ) -> AHMInfoViewModel

    func createAssetDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model

    func createStakingDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model
}

final class AHMInfoViewModelFactory {
    private let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let dateFormatter = DateFormatter.fullDate

    init(assetFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()) {
        self.assetFormatterFactory = assetFormatterFactory
    }
}

// MARK: - Private

private extension AHMInfoViewModelFactory {
    func createFeatures(
        from info: AHMRemoteData,
        sourceChain: ChainModel,
        destinationChain: ChainModel,
        locale: Locale
    ) -> [AHMInfoViewModel.Feature] {
        var features: [AHMInfoViewModel.Feature] = []

        guard
            let sourceAsset = sourceChain.asset(for: info.sourceData.assetId),
            let destinationAsset = destinationChain.asset(for: info.destinationData.assetId)
        else {
            return features
        }

        // Min balance reduction
        let minBalanceReduction = calculateReduction(
            from: info.sourceData.minBalance,
            to: info.destinationData.minBalance
        )

        let sourceMinBalance = formatBalance(
            info.sourceData.minBalance,
            asset: sourceAsset,
            locale: locale
        )
        let destMinBalance = formatBalance(
            info.destinationData.minBalance,
            asset: destinationAsset,
            locale: locale
        )

        features.append(
            AHMInfoViewModel.Feature(
                emoji: "👛",
                text: R.string.localizable.ahmInfoFeatureMinBalance(
                    minBalanceReduction,
                    sourceMinBalance,
                    destMinBalance,
                    preferredLanguages: locale.rLanguages
                )
            )
        )

        // Fee reduction
        let feeReduction = calculateReduction(
            from: info.sourceData.averageFee,
            to: info.destinationData.averageFee
        )

        let sourceFee = formatBalance(
            info.sourceData.averageFee,
            asset: sourceAsset,
            locale: locale
        )
        let destFee = formatBalance(
            info.destinationData.averageFee,
            asset: destinationAsset,
            locale: locale
        )

        features.append(
            AHMInfoViewModel.Feature(
                emoji: "💸",
                text: R.string.localizable.ahmInfoFeatureFees(
                    feeReduction,
                    sourceFee,
                    destFee,
                    preferredLanguages: locale.rLanguages
                )
            )
        )

        // More tokens
        let tokensList = info.newTokenNames.joined(with: .commaSpace)
        features.append(
            AHMInfoViewModel.Feature(
                emoji: "🪙",
                text: R.string.localizable.ahmInfoFeatureTokens(
                    tokensList,
                    preferredLanguages: locale.rLanguages
                )
            )
        )

        // Unified access
        features.append(
            AHMInfoViewModel.Feature(
                emoji: "🗂️",
                text: R.string.localizable.ahmInfoFeatureUnified(
                    sourceAsset.symbol,
                    preferredLanguages: locale.rLanguages
                )
            )
        )

        // Pay fees in any token
        features.append(
            AHMInfoViewModel.Feature(
                emoji: "🧾",
                text: R.string.localizable.ahmInfoFeaturePayFees(preferredLanguages: locale.rLanguages)
            )
        )

        return features
    }

    func calculateReduction(
        from source: BigUInt,
        to destination: BigUInt
    ) -> Int {
        guard destination > 0 else { return 0 }

        return Int(source / destination)
    }

    func formatBalance(
        _ value: BigUInt,
        asset: AssetModel,
        locale: Locale
    ) -> String {
        let assetInfo = asset.displayInfo
        let formatter = assetFormatterFactory.createTokenFormatter(
            for: assetInfo,
            roundingMode: .down
        )

        return formatter
            .value(for: locale)
            .stringFromDecimal(
                value.decimal(assetInfo: assetInfo)
            ) ?? ""
    }
}

// MARK: - AHMInfoViewModelFactoryProtocol

extension AHMInfoViewModelFactory: AHMInfoViewModelFactoryProtocol {
    func createViewModel(
        from info: AHMRemoteData,
        sourceChain: ChainModel,
        destinationChain: ChainModel,
        bannerState: BannersState,
        locale: Locale
    ) -> AHMInfoViewModel {
        let date = Date(timeIntervalSince1970: TimeInterval(info.timestamp))
        let sourceAsset = sourceChain.asset(for: info.sourceData.assetId)
        let tokenSymbol = sourceAsset?.symbol ?? ""

        let title = R.string.localizable.ahmInfoTitle(
            dateFormatter.value(for: locale).string(from: date),
            tokenSymbol,
            destinationChain.name,
            preferredLanguages: locale.rLanguages
        )
        let subtitle = R.string.localizable.ahmInfoSubtitle(
            preferredLanguages: locale.rLanguages
        )

        let features = createFeatures(
            from: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            locale: locale
        )

        let info: [AHMInfoViewModel.Info] = [
            AHMInfoViewModel.Info(
                type: .history,
                text: R.string.localizable.ahmInfoHistoryInfo(
                    sourceChain.name,
                    preferredLanguages: locale.rLanguages
                )
            ),
            AHMInfoViewModel.Info(
                type: .migration,
                text: R.string.localizable.ahmInfoMigrationInfo(
                    preferredLanguages: locale.rLanguages
                )
            )
        ]

        return AHMInfoViewModel(
            bannerState: bannerState,
            title: title,
            subtitle: subtitle,
            features: features,
            info: info,
            actionButtonTitle: R.string.localizable.commonGotIt(preferredLanguages: locale.rLanguages)
        )
    }

    func createAssetDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model {
        let languages = locale.rLanguages

        let date = Date(timeIntervalSince1970: TimeInterval(info.info.timestamp))

        let formattedDate = DateFormatter
            .fullDate
            .value(for: locale)
            .string(from: date)

        let title = R.string.localizable.ahmInfoAlertAssetDetailsTitle(
            info.asset.symbol,
            info.destinationChain.name,
            preferredLanguages: languages
        )
        let message = R.string.localizable.ahmInfoAlertAssetDetailsMessage(
            formattedDate,
            info.asset.symbol,
            info.destinationChain.name,
            preferredLanguages: languages
        )
        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: R.string.localizable.commonLearnMore(
                preferredLanguages: languages
            )
        )
        let actionTitle = R.string.localizable.ahmInfoAlertAssetDetailsAction(
            info.destinationChain.name,
            preferredLanguages: languages
        )

        return AHMAlertView.Model(
            title: title,
            message: message,
            learnMore: learnMoreModel,
            actionTitle: actionTitle
        )
    }

    func createStakingDetailsAlertViewModel(
        info: AHMFullInfo,
        locale: Locale
    ) -> AHMAlertView.Model {
        let languages = locale.rLanguages

        let date = Date(timeIntervalSince1970: TimeInterval(info.info.timestamp))

        let formattedDate = DateFormatter
            .fullDate
            .value(for: locale)
            .string(from: date)

        let title = R.string.localizable.ahmInfoAlertStakingDetailsMessage(
            info.asset.symbol,
            info.destinationChain.name,
            formattedDate,
            preferredLanguages: languages
        )
        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: R.string.localizable.commonLearnMore(
                preferredLanguages: languages
            )
        )

        return AHMAlertView.Model(
            title: title,
            message: nil,
            learnMore: learnMoreModel,
            actionTitle: nil
        )
    }
}
