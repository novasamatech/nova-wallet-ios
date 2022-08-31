import Foundation
import SoraFoundation
import UIKit

enum LedgerMessageSheetViewFactory {
    static func createVerifyLedgerView(
        for deviceName: String,
        address: String,
        cancelClosure: @escaping () -> Void
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.ledgerReviewApprove(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerAddressVerifyMessage(deviceName, preferredLanguages: locale.rLanguages)
        }

        let graphicsViewModel = R.image.imageLedgerApprove()

        let viewModel = MessageSheetViewModel<UIImage, String>(
            title: title,
            message: message,
            graphics: graphicsViewModel,
            content: address.twoLineAddress,
            mainAction: nil,
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetContentLabel>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.allowsSwipeDown = true
        view.closeOnSwipeDownClosure = cancelClosure

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 396.0)

        presenter.view = view

        return view
    }

    static func createReviewLedgerTransactionView(
        for timerMediator: CountdownTimerMediator,
        deviceName: String,
        cancelClosure: @escaping () -> Void
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.ledgerReviewApprove(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerSignTransactionDetails(deviceName, preferredLanguages: locale.rLanguages)
        }

        let graphicsViewModel = R.image.imageLedgerApprove()

        let viewModel = MessageSheetViewModel<UIImage, CountdownTimerMediator>(
            title: title,
            message: message,
            graphics: graphicsViewModel,
            content: timerMediator,
            mainAction: nil,
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetTimerLabel>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.allowsSwipeDown = true
        view.closeOnSwipeDownClosure = cancelClosure

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 360.0)

        presenter.view = view

        return view
    }

    static func createLedgerWarningView(
        for title: LocalizableResource<String>,
        message: LocalizableResource<String>,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: MessageSheetCallback? = nil
    ) -> MessageSheetViewProtocol? {
        let image = R.image.imageLedgerWarning()

        let mainAction: MessageSheetAction

        if let retryClosure = retryClosure {
            mainAction = .retryAction(for: retryClosure)
        } else {
            mainAction = .okBackAction(for: cancelClosure)
        }

        let secondaryAction: MessageSheetAction?

        if retryClosure != nil {
            secondaryAction = .cancelAction(for: cancelClosure)
        } else {
            secondaryAction = nil
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: image,
            content: nil,
            mainAction: mainAction,
            secondaryAction: secondaryAction
        )

        let view = MessageSheetViewFactory.createNoContentView(viewModel: viewModel, allowsSwipeDown: false)

        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 400.0)

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

        return createLedgerWarningView(for: title, message: message, cancelClosure: completionClosure)
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

        return createLedgerWarningView(for: title, message: message, cancelClosure: completionClosure)
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

        return createLedgerWarningView(for: title, message: message, cancelClosure: completionClosure)
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

        return createLedgerWarningView(for: title, message: message, cancelClosure: completionClosure)
    }

    static func createDeviceNotConnectedView(
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerOperationErrorTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerOperationDeviceNotConnected(preferredLanguages: locale.rLanguages)
        }

        return createLedgerWarningView(
            for: title,
            message: message,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure
        )
    }

    static func createOperationCancelledView(
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerOperationTitleCancelled(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerOperationMessageCancelled(preferredLanguages: locale.rLanguages)
        }

        return createLedgerWarningView(
            for: title,
            message: message,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure
        )
    }

    static func createNetworkAppNotLaunchedView(
        chainName: String,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { _ in
            R.string.localizable.ledgerAppNotOpenTitle(chainName)
        }

        let message = LocalizableResource { _ in
            R.string.localizable.ledgerAppNotOpenMessage(chainName)
        }

        return createLedgerWarningView(
            for: title,
            message: message,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure
        )
    }

    static func createMessageErrorView(
        message: String,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerOperationErrorTitle(preferredLanguages: locale.rLanguages)
        }

        return createLedgerWarningView(
            for: title,
            message: LocalizableResource { _ in message },
            cancelClosure: cancelClosure,
            retryClosure: retryClosure
        )
    }

    static func createUnknownErrorView(
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerOperationErrorTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerOperationMessageError(preferredLanguages: locale.rLanguages)
        }

        return createLedgerWarningView(
            for: title,
            message: message,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure
        )
    }
}
