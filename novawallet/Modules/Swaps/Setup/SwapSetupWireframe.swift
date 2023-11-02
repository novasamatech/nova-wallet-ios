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

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        initState: SwapConfirmInitState
    ) {
        guard let confimView = SwapConfirmViewFactory.createView(
            initState: initState
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confimView.controller,
            animated: true
        )
    }

    func showNetworkFeeAssetSelection(
        form view: ControllerBackedProtocol?,
        viewModel: SwapNetworkFeeSheetViewModel
    ) {
        let bottomSheet = SwapNetworkFeeSheetViewFactory.createView(from: viewModel)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func showTokenDepositOptions(
        form view: ControllerBackedProtocol?,
        operations: [(token: TokenOperation, active: Bool)],
        token: String,
        delegate: ModalPickerViewControllerDelegate?
    ) {
        guard let bottomSheet = ModalPickerFactory.createPickerListForOperations(
            operations: operations,
            delegate: delegate,
            token: token,
            context: nil
        ) else {
            return
        }

        view?.controller.present(bottomSheet, animated: true)
    }
}
