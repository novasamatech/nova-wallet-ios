import UIKit
import UIKit_iOS

protocol SubtensorSortSheetPresentable {
    func showSortSheet(
        from view: ControllerBackedProtocol?,
        viewModel: SubtensorSortSheetViewModel,
        delegate: SubtensorSortSheetDelegate
    )
}

extension SubtensorSortSheetPresentable {
    func showSortSheet(
        from view: ControllerBackedProtocol?,
        viewModel: SubtensorSortSheetViewModel,
        delegate: SubtensorSortSheetDelegate
    ) {
        let sortSheet = SubtensorSortSheetViewController(viewModel: viewModel, delegate: delegate)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)

        sortSheet.modalTransitioningFactory = factory
        sortSheet.modalPresentationStyle = .custom

        view?.controller.present(sortSheet, animated: true)
    }
}
