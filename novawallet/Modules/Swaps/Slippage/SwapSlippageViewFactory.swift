import Foundation
import Foundation_iOS

struct SwapSlippageViewFactory {
    static func createView(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let wireframe = SwapSlippageWireframe()

        let amountFormatter = NumberFormatter.amount
        amountFormatter.maximumFractionDigits = 4
        amountFormatter.maximumSignificantDigits = 4

        let percentFormatter = NumberFormatter.percentSingle

        let presenter = SwapSlippagePresenter(
            wireframe: wireframe,
            percentFormatterLocalizable: percentFormatter.localizableResource(),
            localizationManager: LocalizationManager.shared,
            initSlippage: percent,
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
