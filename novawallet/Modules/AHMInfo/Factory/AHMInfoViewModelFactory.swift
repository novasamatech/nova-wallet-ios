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
                text: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.ahmInfoFeatureMinBalance(
                    minBalanceReduction,
                    sourceMinBalance,
                    destMinBalance
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
                text: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.ahmInfoFeatureFees(
                    feeReduction,
                    sourceFee,
                    destFee
                )
            )
        )

        // More tokens
        let tokensList = info.newTokenNames.joined(with: .commaSpace)
        features.append(
            AHMInfoViewModel.Feature(
                emoji: "🪙",
                text: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.ahmInfoFeatureTokens(
                    tokensList
                )
            )
        )

        // Unified access
        features.append(
            AHMInfoViewModel.Feature(
                emoji: "🗂️",
                text: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.ahmInfoFeatureUnified(
                    sourceAsset.symbol
                )
            )
        )

        // Pay fees in any token
        features.append(
            AHMInfoViewModel.Feature(
                emoji: "🧾",
                text: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.ahmInfoFeaturePayFees()
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

        let title = if info.migrationInProgress {
            R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.ahmInfoInProgressTitle(
                dateFormatter.value(for: locale).string(from: date),
                tokenSymbol,
                destinationChain.name
            )
        } else {
            R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.ahmInfoTitle(
                dateFormatter.value(for: locale).string(from: date),
                tokenSymbol,
                destinationChain.name
            )
        }

        let subtitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoSubtitle()

        let features = createFeatures(
            from: info,
            sourceChain: sourceChain,
            destinationChain: destinationChain,
            locale: locale
        )

        let info: [AHMInfoViewModel.Info] = [
            AHMInfoViewModel.Info(
                type: .history,
                text: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.ahmInfoHistoryInfo(
                    sourceChain.name
                )
            ),
            AHMInfoViewModel.Info(
                type: .migration,
                text: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.ahmInfoMigrationInfo()
            )
        ]

        return AHMInfoViewModel(
            bannerState: bannerState,
            title: title,
            subtitle: subtitle,
            features: features,
            info: info,
            actionButtonTitle: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonGotIt()
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

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertAssetDetailsTitle(
            info.asset.symbol,
            info.destinationChain.name
        )
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertAssetDetailsMessage(
            formattedDate,
            info.asset.symbol,
            info.destinationChain.name
        )
        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonLearnMore()
        )
        let actionTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertAssetDetailsAction(
            info.destinationChain.name
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
        let sourceChainAsset = ChainAsset(
            chain: info.sourceChain,
            asset: info.asset
        )
        let languages = locale.rLanguages

        let date = Date(timeIntervalSince1970: TimeInterval(info.info.timestamp))

        let formattedDate = DateFormatter
            .fullDate
            .value(for: locale)
            .string(from: date)

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.ahmInfoAlertStakingDetailsMessage(
            sourceChainAsset.chainAssetName,
            info.destinationChain.name,
            formattedDate
        )
        let learnMoreModel = LearnMoreViewModel(
            iconViewModel: nil,
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonLearnMore()
        )

        return AHMAlertView.Model(
            title: title,
            message: nil,
            learnMore: learnMoreModel,
            actionTitle: nil
        )
    }
}
