import UIKit
import UIKit_iOS

protocol SubtensorSortSheetPresentable {
    func showSortSheet(
        from view: ControllerBackedProtocol?,
        viewModel: SubtensorSortSheetViewModel,
        onSelect: @escaping (Int) -> Void
    )
}

extension SubtensorSortSheetPresentable {
    func showSortSheet(
        from view: ControllerBackedProtocol?,
        viewModel: SubtensorSortSheetViewModel,
        onSelect: @escaping (Int) -> Void
    ) {
        let sortSheet = SubtensorSortSheetViewController(viewModel: viewModel, onSelect: onSelect)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)

        sortSheet.modalTransitioningFactory = factory
        sortSheet.modalPresentationStyle = .custom

        view?.controller.present(sortSheet, animated: true)
    }
}
