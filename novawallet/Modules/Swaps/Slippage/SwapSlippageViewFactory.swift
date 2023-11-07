import Foundation
import SoraFoundation

struct SwapSlippageViewFactory {
    static func createView(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let wireframe = SwapSlippageWireframe()

        let amountFormatter = NumberFormatter.amount
        let percentFormatter = NumberFormatter.percentSingle

        let presenter = SwapSlippagePresenter(
            wireframe: wireframe,
            numberFormatterLocalizable: amountFormatter.localizableResource(),
            percentFormatterLocalizable: percentFormatter.localizableResource(),
            localizationManager: LocalizationManager.shared,
            initSlippage: percent?.toPercents(),
            config: SlippageConfig.defaultConfig,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        )

        let view = SwapSlippageViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
