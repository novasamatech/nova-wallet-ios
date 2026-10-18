import Foundation
import Foundation_iOS
import UIKit_iOS

extension SwapSlippageViewFactory {
    static func createSubtensorView(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        createView(
            percent: percent,
            chainAsset: chainAsset,
            config: SlippageConfig.subtensorStaking,
            completionHandler: completionHandler
        )
    }

    static func createSubtensorSheet(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let presenter = SwapSlippagePresenter(
            wireframe: SubtensorSlippageSheetWireframe(),
            percentFormatterLocalizable: NumberFormatter.percentSingle.localizableResource(),
            localizationManager: LocalizationManager.shared,
            initSlippage: percent,
            config: SlippageConfig.subtensorStaking,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        )

        let view = SwapSlippageViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            presentation: .subtensorSheet
        )

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom
        view.preferredContentSize = CGSize(width: 0, height: SubtensorSlippageSheetConstants.height)

        return view
    }
}

private final class SubtensorSlippageSheetWireframe: SwapSlippageWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}

private enum SubtensorSlippageSheetConstants {
    static let height: CGFloat = 430
}
