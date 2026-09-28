import UIKit
import Foundation_iOS
import UIKit_iOS

protocol SubtensorInfoSheetPresentable: AddressOptionsPresentable {
    func showSubtensorInfo(_ sheet: SubtensorInfoSheet, from view: ControllerBackedProtocol?)
}

extension SubtensorInfoSheetPresentable {
    func showSubtensorInfo(_ sheet: SubtensorInfoSheet, from view: ControllerBackedProtocol?) {
        guard let view else {
            return
        }

        if case let .account(address, chain) = sheet {
            presentAccountOptions(
                from: view,
                address: address,
                chain: chain,
                locale: LocalizationManager.shared.selectedLocale
            )

            return
        }

        guard let text = sheet.text else {
            return
        }

        let gotItAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonGotIt()
            },
            handler: {}
        )

        let viewModel = TitleDetailsSheetViewModel(
            title: text.title,
            message: text.details,
            mainAction: gotItAction,
            secondaryAction: nil
        )

        let bottomSheet = TitleDetailsSheetViewFactory.createContentSizedView(from: viewModel)

        if let titleDetailsView = bottomSheet as? TitleDetailsSheetViewController {
            titleDetailsView.rootView.titleLabel.apply(style: .boldTitle3Primary)
            titleDetailsView.preferredContentSize.height = titleDetailsView.rootView.contentHeight(
                model: viewModel,
                locale: LocalizationManager.shared.selectedLocale
            )
        }

        bottomSheet.controller.preferredContentSize.height += SubtensorInfoSheetConstants.actionTopSpacing

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view.controller.present(bottomSheet.controller, animated: true)
    }
}

private enum SubtensorInfoSheetConstants {
    static let actionTopSpacing: CGFloat = 24
}
