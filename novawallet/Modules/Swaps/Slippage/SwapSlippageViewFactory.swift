import Foundation
import Foundation_iOS
import UIKit_iOS

struct SwapSlippageViewFactory {
    static func createSettingsSheet(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        let presenter = SwapSlippagePresenter(
            wireframe: SwapSlippageSheetWireframe(),
            percentFormatterLocalizable: NumberFormatter.percentSingle.localizableResource(),
            localizationManager: LocalizationManager.shared,
            initSlippage: percent,
            config: SlippageConfig.defaultConfig,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        )

        let view = SubtensorSlippageViewController(
            presenter: presenter,
            configuration: .swap,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom

        return view
    }
}
