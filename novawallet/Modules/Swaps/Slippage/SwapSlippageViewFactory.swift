import Foundation
import Foundation_iOS

enum SwapSlippageViewFactory {
    static func createView(
        percent: BigRational?,
        chainAsset: ChainAsset,
        config: SlippageConfig = SlippageConfig.defaultConfig,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let wireframe = SwapSlippageWireframe()

        let percentFormatter = NumberFormatter.percentSingle

        let presenter = SwapSlippagePresenter(
            wireframe: wireframe,
            percentFormatterLocalizable: percentFormatter.localizableResource(),
            localizationManager: LocalizationManager.shared,
            initSlippage: percent,
            config: config,
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
