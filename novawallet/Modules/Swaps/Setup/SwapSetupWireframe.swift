import Foundation
import SoraFoundation
import SoraUI

final class SwapSetupWireframe: SwapSetupWireframeProtocol {
    let assetListObservable: AssetListModelObservable

    init(assetListObservable: AssetListModelObservable) {
        self.assetListObservable = assetListObservable
    }

    func showPayTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectPayTokenView(
            for: assetListObservable,
            chainAsset: chainAsset,
            selectClosure: completionHandler
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectTokenView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showReceiveTokenSelection(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset?,
        completionHandler: @escaping (ChainAsset) -> Void
    ) {
        guard let selectTokenView = SwapAssetsOperationViewFactory.createSelectReceiveTokenView(
            for: assetListObservable,
            chainAsset: chainAsset,
            selectClosure: completionHandler
        ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: selectTokenView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
    func showSettings(
        from view: ControllerBackedProtocol?,
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) {
        guard let settingsView = SwapSlippageViewFactory.createView(
            percent: percent,
            chainAsset: chainAsset,
            completionHandler: completionHandler
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            settingsView.controller,
            animated: true
        )
    }
    func showInfo(
        from view: ControllerBackedProtocol?,
        title: LocalizableResource<String>,
        details: LocalizableResource<String>
    ) {
        let viewModel = TitleDetailsSheetViewModel(
            title: title,
            message: details,
            mainAction: nil,
            secondaryAction: nil
        )

        let bottomSheet = TitleDetailsSheetViewFactory.createContentSizedView(from: viewModel)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }
}
