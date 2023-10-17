import Foundation
import SoraFoundation

struct SwapSlippageViewFactory {
    static func createView(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let interactor = SwapSlippageInteractor()
        let wireframe = SwapSlippageWireframe()

        let amountFormatter = NumberFormatter.amount
        let percentFormatter = NumberFormatter.percentSingle

        let presenter = SwapSlippagePresenter(
            interactor: interactor,
            wireframe: wireframe,
            numberFormatterLocalizable: amountFormatter.localizableResource(),
            percentFormatterLocalizable: percentFormatter.localizableResource(),
            localizationManager: LocalizationManager.shared,
            initPercent: percent,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        )

        let view = SwapSlippageViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
