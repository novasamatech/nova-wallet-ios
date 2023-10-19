import Foundation
import BigInt
import SoraFoundation

protocol SwapDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
}

final class SwapDataValidatorFactoryProtocol: SwapDataValidatorFactoryProtocol {
    weak var view: (Localizable & ControllerBackedProtocol)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: SwapErrorPresentable

    init(
        presentable: TransferErrorPresentable,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        utilityAssetInfo: AssetBalanceDisplayInfo?,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.presentable = presentable
    }
}
