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
}

final class AHMInfoViewModelFactory {
    private let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

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
        dateFormatter.locale = locale

        let date = Date(timeIntervalSince1970: TimeInterval(info.timestamp))
        let sourceAsset = sourceChain.asset(for: info.sourceData.assetId)
        let tokenSymbol = sourceAsset?.symbol ?? ""

        let title = R.string.localizable.ahmInfoTitle(
            dateFormatter.string(from: date),
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
}
