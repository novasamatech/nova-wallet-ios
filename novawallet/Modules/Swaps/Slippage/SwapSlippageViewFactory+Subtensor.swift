import Foundation
import Foundation_iOS
import UIKit_iOS

extension SwapSlippageViewFactory {
    static func createSubtensorSheet(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let presenter = SwapSlippagePresenter(
            wireframe: SubtensorSlippageSheetWireframe(),
            percentFormatterLocalizable: NumberFormatter.subtensorPercentSingle,
            localizationManager: LocalizationManager.shared,
            initSlippage: percent,
            config: SlippageConfig.subtensorStaking,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        )

        let view = SubtensorSlippageViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom

        return view
    }
}

private final class SubtensorSlippageSheetWireframe: SwapSlippageWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
