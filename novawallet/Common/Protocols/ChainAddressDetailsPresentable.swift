import Foundation
import SoraUI

protocol ChainAddressDetailsPresentable {
    func presentChainAddressDetails(from presentationView: ControllerBackedProtocol, model: ChainAddressDetailsModel)
}

extension ChainAddressDetailsPresentable {
    func presentChainAddressDetails(from presentationView: ControllerBackedProtocol, model: ChainAddressDetailsModel) {
        guard let detailsView = ChainAddressDetailsPresentableFactory.createChainAddressDetails(for: model) else {
            return
        }

        presentationView.controller.present(detailsView.controller, animated: true, completion: nil)
    }
}

enum ChainAddressDetailsPresentableFactory {
    static func createChainAddressDetails(for model: ChainAddressDetailsModel) -> ChainAddressDetailsViewProtocol? {
        guard let detailsView = ChainAddressDetailsViewFactory.createView(for: model) else {
            return nil
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)

        detailsView.controller.modalTransitioningFactory = factory
        detailsView.controller.modalPresentationStyle = .custom

        return detailsView
    }
}
