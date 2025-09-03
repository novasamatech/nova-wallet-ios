import UIKit
import Foundation
import Foundation_iOS
import UIKit_iOS

enum MultisigNotificationsSheetFactory {
    static func createMultisigNotificationsPromo(
        enableSettingsClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.multisigNotificationsPromoSheetTitle(
                preferredLanguages: locale.rLanguages
            )
        }
        let message = LocalizableResource { locale in
            R.string.localizable.multisigNotificationsPromoSheetMessage(
                preferredLanguages: locale.rLanguages
            )
        }

        let enableSettingsAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string.localizable.commonEnableSettings(preferredLanguages: locale.rLanguages)
            },
            handler: enableSettingsClosure
        )

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.iconNotificationRing(),
            content: nil,
            mainAction: enableSettingsAction,
            secondaryAction: .notNowAction(for: {})
        )

        let view = MessageSheetViewFactory.createNoContentView(viewModel: viewModel, allowsSwipeDown: true)
        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 312.0)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view?.controller.modalTransitioningFactory = factory
        view?.controller.modalPresentationStyle = .custom

        return view
    }
}
