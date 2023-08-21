import Foundation

protocol TokenAddValidationFactoryProtocol {
    func decimalsNotExceedMax(for decimals: UInt8, maxValue: UInt8, locale: Locale) -> DataValidating

    func noRemoteToken(
        for contractAddress: AccountAddress,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating

    func warnDuplicates(
        for contractAddress: AccountAddress,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating
}

final class TokenAddValidationFactory {
    weak var view: ControllerBackedProtocol?
    let wireframe: TokenAddErrorPresentable

    init(wireframe: TokenAddErrorPresentable) {
        self.wireframe = wireframe
    }
}

extension TokenAddValidationFactory: TokenAddValidationFactoryProtocol {
    func decimalsNotExceedMax(for decimals: UInt8, maxValue: UInt8, locale: Locale) -> DataValidating {
        ErrorConditionViolation(
            onError: { [weak self] in
                guard let view = self?.view else {
                    return
                }

                self?.wireframe.presentInvalidDecimals(
                    from: view,
                    maxValue: String(maxValue),
                    locale: locale
                )
            },
            preservesCondition: {
                decimals <= maxValue
            }
        )
    }

    func noRemoteToken(
        for contractAddress: AccountAddress,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating {
        let assetId = AssetModel.createAssetId(from: contractAddress)
        let optAsset = chain.assets.first(where: { $0.assetId == assetId })

        return ErrorConditionViolation(
            onError: { [weak self] in
                guard let view = self?.view, let asset = optAsset else {
                    return
                }

                self?.wireframe.presentTokenAlreadyExists(
                    from: view,
                    symbol: asset.symbol,
                    locale: locale
                )
            },
            preservesCondition: {
                optAsset?.source != .remote
            }
        )
    }

    func warnDuplicates(
        for contractAddress: AccountAddress,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating {
        let assetId = AssetModel.createAssetId(from: contractAddress)
        let optAsset = chain.assets.first(where: { $0.assetId == assetId })

        return WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view, let asset = optAsset else {
                return
            }

            self?.wireframe.presentTokenUpdate(
                from: view,
                symbol: asset.symbol,
                onContinue: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            optAsset == nil
        })
    }
}
