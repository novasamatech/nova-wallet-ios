import Foundation
import SoraFoundation

enum LedgerBottomSheetViewFactory {
    private enum Constants {
        static let ledgerInfoRenderSize = CGSize(width: 100.0, height: 72.0)
    }

    static func createVerifyLedgerView(for deviceName: String) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe(completionCallback: nil)

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.ledgerAddressVerifyTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerAddressVerifyMessage(deviceName, preferredLanguages: locale.rLanguages)
        }

        let hint = LocalizableResource { locale in
            R.string.localizable.ledgerAddressVerifyConfirmation(preferredLanguages: locale.rLanguages)
        }

        let graphicsViewModel = MessageSheetLedgerViewModel(
            backgroundImage: R.image.graphicsLedgerVerify()!,
            text: hint,
            icon: R.image.iconEye14()!,
            infoRenderSize: Constants.ledgerInfoRenderSize
        )

        let viewModel = MessageSheetViewModel<MessageSheetLedgerViewModel, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: graphicsViewModel,
            content: nil,
            hasAction: false
        )

        let view = MessageSheetViewController<MessageSheetLedgerView, MessageSheetNoContentView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 320.0)

        presenter.view = view

        return view
    }

    static func createReviewLedgerTransactionView(
        for timerMediator: CountdownTimerMediator,
        deviceName: String
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe(completionCallback: nil)

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.commonSignTransaction(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerSignTransactionDetails(deviceName, preferredLanguages: locale.rLanguages)
        }

        let hint = LocalizableResource { locale in
            R.string.localizable.ledgerReviewTransactionConfirmation(preferredLanguages: locale.rLanguages)
        }

        let graphicsViewModel = MessageSheetLedgerViewModel(
            backgroundImage: R.image.graphicsLedgerVerify()!,
            text: hint,
            icon: R.image.iconEye14()!,
            infoRenderSize: Constants.ledgerInfoRenderSize
        )

        let viewModel = MessageSheetViewModel<MessageSheetLedgerViewModel, CountdownTimerMediator>(
            title: title,
            message: message,
            graphics: graphicsViewModel,
            content: timerMediator,
            hasAction: false
        )

        let view = MessageSheetViewController<MessageSheetLedgerView, MessageSheetTimerLabel>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 360.0)

        presenter.view = view

        return view
    }

    static func createLedgerWarningView(
        for title: LocalizableResource<String>,
        message: LocalizableResource<String>,
        completionClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let image = R.image.imageLedgerWarning()

        let view = MessageSheetViewFactory.createNoContentView(
            title: title,
            message: message,
            image: image,
            allowsSwipeDown: false,
            completionCallback: completionClosure
        )

        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 380.0)

        return view
    }

    static func createTransactionExpiredView(
        for expirationTimeInterval: TimeInterval,
        completionClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.commonTransactionExpired(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource<String> { locale in
            let minutes = R.string.localizable.commonMinutesFormat(
                format: expirationTimeInterval.minutesFromSeconds,
                preferredLanguages: locale.rLanguages
            )

            return R.string.localizable.ledgerTransactionExpiredDetails(
                minutes,
                preferredLanguages: locale.rLanguages
            )
        }

        return createLedgerWarningView(for: title, message: message, completionClosure: completionClosure)
    }

    static func createTransactionNotSupportedView(
        completionClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerTransactionNotSupportedTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource<String> { locale in
            R.string.localizable.ledgerTransactionNotSupportedMessage(
                preferredLanguages: locale.rLanguages
            )
        }

        return createLedgerWarningView(for: title, message: message, completionClosure: completionClosure)
    }

    static func createSignatureInvalidView(
        completionClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.commonSignatureInvalid(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource<String> { locale in
            R.string.localizable.ledgerTransactionSignatureInvalid(
                preferredLanguages: locale.rLanguages
            )
        }

        return createLedgerWarningView(for: title, message: message, completionClosure: completionClosure)
    }

    static func createMetadataOutdatedView(
        chainName: String,
        completionClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.commonOutdatedMetadata(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource<String> { locale in
            R.string.localizable.ledgerTransactionUpdateMetadata(
                chainName,
                preferredLanguages: locale.rLanguages
            )
        }

        return createLedgerWarningView(for: title, message: message, completionClosure: completionClosure)
    }
}
