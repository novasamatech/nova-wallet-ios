import UIKit
import Foundation
import Foundation_iOS
import UIKit_iOS

enum AnalyticsConsentSheetFactory {
    /// Takes no `Locale`: the `LocalizableResource` closures are resolved by
    /// `MessageSheetViewController` at display time through `LocalizationManager.shared`,
    /// and re-resolved when the in-app language changes.
    static func createConsentSheet(
        onEnable: @escaping MessageSheetCallback,
        onDecline: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.analyticsPromptTitle()
        }
        let message = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.analyticsPromptMessage()
        }

        let enableAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.analyticsPromptEnable()
            },
            handler: onEnable
        )

        let declineAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.analyticsPromptDecline()
            },
            handler: onDecline
        )

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageAnalyticsConsent(),
            content: nil,
            mainAction: enableAction,
            secondaryAction: declineAction
        )

        // `allowsSwipeDown: false` forces a decision: either branch must persist
        // `analyticsPromptSeen` and advance the launch queue, and a swipe-down would do neither.
        let view = MessageSheetViewFactory.createNoContentView(viewModel: viewModel, allowsSwipeDown: false)
        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 360.0)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.novaManual)
        view?.controller.modalTransitioningFactory = factory
        view?.controller.modalPresentationStyle = .custom

        return view
    }
}
