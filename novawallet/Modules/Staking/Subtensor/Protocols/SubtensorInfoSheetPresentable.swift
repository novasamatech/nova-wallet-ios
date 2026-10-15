import UIKit
import Foundation_iOS
import UIKit_iOS

protocol SubtensorInfoSheetPresentable: AddressOptionsPresentable, ShortTextInfoPresentable {
    func showSubtensorInfo(_ sheet: SubtensorInfoSheet, from view: ControllerBackedProtocol?)
}

extension SubtensorInfoSheetPresentable {
    func showSubtensorInfo(_ sheet: SubtensorInfoSheet, from view: ControllerBackedProtocol?) {
        guard let view else {
            return
        }

        let locale = LocalizationManager.shared.selectedLocale

        let gotItAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonGotIt()
            },
            handler: {}
        )

        let viewModel = TitleDetailsSheetViewModel(
            title: sheet.title,
            message: sheet.details,
            mainAction: gotItAction,
            secondaryAction: nil
        )

        let bottomSheet = TitleDetailsSheetViewFactory.createContentSizedView(from: viewModel)

        if let titleDetailsView = bottomSheet as? TitleDetailsSheetViewController {
            titleDetailsView.rootView.apply(style: TitleDetailsSheetViewLayout.Style(
                title: .boldTitle3Primary,
                detailsLineHeight: 18,
                spacing: 12,
                actionsBottomInset: 0
            ))
            titleDetailsView.rootView.bind(details: sheet.details.value(for: locale))
            titleDetailsView.preferredContentSize.height = titleDetailsView.rootView.contentHeight(
                model: viewModel,
                locale: locale
            )
        }

        bottomSheet.controller.preferredContentSize.height += 24
        bottomSheet.controller.modalTransitioningFactory = ModalSheetPresentationFactory(configuration: .novaManual)
        bottomSheet.controller.modalPresentationStyle = .custom

        view.controller.present(bottomSheet.controller, animated: true)
    }
}
