import UIKit
import Foundation_iOS
import UIKit_iOS

protocol ShortTextInfoPresentable {}

extension ShortTextInfoPresentable {
    func showInfo(
        from view: ControllerBackedProtocol?,
        title: LocalizableResource<String>,
        details: LocalizableResource<String>,
        mainAction: MessageSheetAction? = nil,
        titleStyle: UILabel.Style? = nil,
        extraHeight: CGFloat = 0
    ) {
        let viewModel = TitleDetailsSheetViewModel(
            title: title,
            message: details,
            mainAction: mainAction,
            secondaryAction: nil
        )

        let bottomSheet = TitleDetailsSheetViewFactory.createContentSizedView(from: viewModel)

        if let titleStyle, let titleDetailsView = bottomSheet as? TitleDetailsSheetViewController {
            titleDetailsView.rootView.titleLabel.apply(style: titleStyle)
            titleDetailsView.preferredContentSize.height = titleDetailsView.rootView.contentHeight(
                model: viewModel,
                locale: LocalizationManager.shared.selectedLocale
            )
        }

        bottomSheet.controller.preferredContentSize.height += extraHeight

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }
}
