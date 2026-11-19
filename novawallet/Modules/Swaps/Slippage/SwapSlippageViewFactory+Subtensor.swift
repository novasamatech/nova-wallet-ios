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
            wireframe: SwapSlippageSheetWireframe(),
            percentFormatterLocalizable: NumberFormatter.subtensorPercentSingle,
            localizationManager: LocalizationManager.shared,
            initSlippage: percent,
            config: SlippageConfig.subtensorStaking,
            chainAsset: chainAsset,
            completionHandler: { newValue in
                SubtensorSlippageAnalytics(config: .subtensorStaking).trackChange(from: percent, to: newValue)
                completionHandler(newValue)
            }
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
