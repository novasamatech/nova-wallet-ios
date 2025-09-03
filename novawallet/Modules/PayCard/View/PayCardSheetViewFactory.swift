import Foundation
import UIKit
import UIKit_iOS
import Foundation_iOS

enum PayCardSheetViewFactory {
    static func createCardFundingSheet(
        for mode: PayCardSheetMode,
        timerMediator: CountdownTimerMediator,
        totalTime: TimeInterval,
        locale: Locale?
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            switch mode {
            case .issue:
                return R.string.localizable.cardOpenPendingSheetTitle(
                    preferredLanguages: locale.rLanguages
                )
            case .topup:
                return R.string.localizable.cardTopupPendingSheetTitle(
                    preferredLanguages: locale.rLanguages
                )
            }
        }

        let message = LocalizableResource { locale in
            let minutesString = R.string.localizable.commonMinutesFormat(
                format: totalTime.minutesFromSeconds,
                preferredLanguages: locale.rLanguages
            )

            return R.string.localizable.cardOpenPendingSheetMessage(
                minutesString,
                preferredLanguages: locale.rLanguages
            )
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetTimerLabel.ContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageCardOpeningTimer(),
            content: timerMediator,
            mainAction: nil,
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetTimerLabel>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 380.0)

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view.controller.modalTransitioningFactory = factory
        view.controller.modalPresentationStyle = .custom

        return view
    }
}
