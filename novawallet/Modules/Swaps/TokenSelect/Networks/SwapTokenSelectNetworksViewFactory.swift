import UIKit
import Foundation_iOS
import UIKit_iOS

enum SwapTokenSelectNetworksViewFactory {
    static func createView(
        viewModels: [SwapTokenSelectNetworkViewModel],
        completion: @escaping ([ChainModel.Id]) -> Void
    ) -> SwapTokenSelectNetworksViewProtocol? {
        let presenter = SwapTokenSelectNetworksPresenter(
            wireframe: SwapTokenSelectNetworksWireframe(),
            viewModels: viewModels,
            completion: completion
        )

        let view = SwapTokenSelectNetworksViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)
        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom

        let height = SwapTokenSelectNetworksViewLayout.Constants.preferredHeight(for: viewModels.count)
        view.preferredContentSize = CGSize(width: 0, height: height)

        return view
    }
}
