import Foundation_iOS
import UIKit_iOS

protocol ShortTextInfoPresentable {
    func showInfo(
        from view: ControllerBackedProtocol?,
        title: LocalizableResource<String>,
        details: LocalizableResource<String>
    )
}

extension ShortTextInfoPresentable {
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
