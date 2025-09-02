import Foundation
import Foundation_iOS
import UIKit

enum LedgerMessageSheetViewFactory {
    static func createVerifyLedgerView(
        for deviceName: String,
        deviceModel: LedgerDeviceModel,
        address: String,
        cancelClosure: @escaping () -> Void
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.ledgerReviewApprove(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            deviceModel.approveAddressText(for: deviceName, locale: locale)
        }

        let viewModel = MessageSheetViewModel<UIImage, String>(
            title: title,
            message: message,
            graphics: deviceModel.approveAddressImage,
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

    static func createVerifyLedgerView(
        for deviceName: String,
        deviceModel: LedgerDeviceModel,
        addresses: [HardwareWalletAddressScheme: AccountAddress],
        cancelClosure: @escaping () -> Void
    ) -> MessageSheetViewProtocol? {
        guard addresses.count > 1 else {
            return addresses.first.flatMap { keyValue in
                createVerifyLedgerView(
                    for: deviceName,
                    deviceModel: deviceModel,
                    address: keyValue.value,
                    cancelClosure: cancelClosure
                )
            }
        }

        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.ledgerReviewApprove(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            deviceModel.approveAddressText(for: deviceName, locale: locale)
        }

        let content = addresses.map { keyValue in
            MessageSheetHWAddressContent.ViewModelItem(
                scheme: keyValue.key,
                address: keyValue.value
            )
        }.sorted { $0.scheme.order < $1.scheme.order }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetHWAddressContent.ContentViewModel>(
            title: title,
            message: message,
            graphics: deviceModel.approveAddressImage,
            content: content,
            mainAction: nil,
            secondaryAction: nil
        )

        let view = MultiAddressMessageSheetViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.allowsSwipeDown = true
        view.closeOnSwipeDownClosure = cancelClosure

        let height = MultiAddressMessageSheetViewController.measureHeight(for: content)
        view.controller.preferredContentSize = CGSize(width: 0.0, height: height)

        presenter.view = view

        return view
    }

    static func createReviewLedgerTransactionView(
        for timerMediator: CountdownTimerMediator,
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        cancelClosure: @escaping () -> Void,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.ledgerReviewApprove(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            deviceModel.approveTxText(for: deviceName, locale: locale)
        }

        if let migrationViewModel {
            let viewModel = MessageSheetViewModel<UIImage, MessageSheetTimerWithBannerView.ContentViewModel>(
                title: title,
                message: message,
                graphics: deviceModel.approveTxImage,
                content: .init(timerViewModel: timerMediator, bannerViewModel: migrationViewModel),
                mainAction: nil,
                secondaryAction: nil
            )

            let view = MessageSheetViewController<MessageSheetImageView, MessageSheetTimerWithBannerView>(
                presenter: presenter,
                viewModel: viewModel,
                localizationManager: LocalizationManager.shared
            )

            view.allowsSwipeDown = true
            view.closeOnSwipeDownClosure = cancelClosure

            view.controller.preferredContentSize = CGSize(width: 0.0, height: 514.0)

            presenter.view = view

            return view
        } else {
            let viewModel = MessageSheetViewModel<UIImage, CountdownTimerMediator>(
                title: title,
                message: message,
                graphics: deviceModel.approveTxImage,
                content: timerMediator,
                mainAction: nil,
                secondaryAction: nil
            )

            let view = MessageSheetViewController<MessageSheetImageView, TxExpirationMessageSheetTimerLabel>(
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
    }

    static func createLedgerWarningView(
        for title: LocalizableResource<String>,
        message: LocalizableResource<String>,
        deviceModel: LedgerDeviceModel,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: MessageSheetCallback? = nil,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?
    ) -> MessageSheetViewProtocol? {
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

        if let migrationViewModel {
            let viewModel = MessageSheetViewModel<UIImage, MessageSheetMigrationBannerView.ContentViewModel>(
                title: title,
                message: message,
                graphics: deviceModel.warningImage,
                content: migrationViewModel,
                mainAction: mainAction,
                secondaryAction: secondaryAction
            )

            let view = MessageSheetViewFactory.createMigrationBannerContentView(
                viewModel: viewModel,
                allowsSwipeDown: false
            )

            view?.controller.preferredContentSize = CGSize(width: 0.0, height: 514)

            return view
        } else {
            let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
                title: title,
                message: message,
                graphics: deviceModel.warningImage,
                content: nil,
                mainAction: mainAction,
                secondaryAction: secondaryAction
            )

            let view = MessageSheetViewFactory.createNoContentView(viewModel: viewModel, allowsSwipeDown: false)

            view?.controller.preferredContentSize = CGSize(width: 0.0, height: 420.0)

            return view
        }
    }

    static func createTransactionExpiredView(
        for expirationTimeInterval: TimeInterval,
        deviceModel: LedgerDeviceModel,
        completionClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
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

        return createLedgerWarningView(
            for: title,
            message: message,
            deviceModel: deviceModel,
            cancelClosure: completionClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createTransactionNotSupportedView(
        deviceModel: LedgerDeviceModel,
        completionClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerTransactionNotSupportedTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource<String> { locale in
            R.string.localizable.ledgerTransactionNotSupportedMessage(
                preferredLanguages: locale.rLanguages
            )
        }

        return createLedgerWarningView(
            for: title,
            message: message,
            deviceModel: deviceModel,
            cancelClosure: completionClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createSignatureInvalidView(
        deviceModel: LedgerDeviceModel,
        completionClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.commonSignatureInvalid(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource<String> { locale in
            R.string.localizable.ledgerTransactionSignatureInvalid(
                preferredLanguages: locale.rLanguages
            )
        }

        return createLedgerWarningView(
            for: title,
            message: message,
            deviceModel: deviceModel,
            cancelClosure: completionClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createMetadataOutdatedView(
        chainName: String,
        deviceModel: LedgerDeviceModel,
        completionClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
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

        return createLedgerWarningView(
            for: title,
            message: message,
            deviceModel: deviceModel,
            cancelClosure: completionClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createDeviceNotConnectedView(
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
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
            deviceModel: .unknown,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createOperationCancelledView(
        deviceModel: LedgerDeviceModel,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
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
            deviceModel: deviceModel,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createNetworkAppNotLaunchedView(
        chainName: String,
        deviceModel: LedgerDeviceModel,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerAppNotOpenTitle(chainName, preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerAppNotOpenMessage(chainName, preferredLanguages: locale.rLanguages)
        }

        return createLedgerWarningView(
            for: title,
            message: message,
            deviceModel: deviceModel,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createMessageErrorView(
        message: String,
        deviceModel: LedgerDeviceModel,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.ledgerOperationErrorTitle(preferredLanguages: locale.rLanguages)
        }

        return createLedgerWarningView(
            for: title,
            message: LocalizableResource { _ in message },
            deviceModel: deviceModel,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createUnknownErrorView(
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel? = nil
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
            deviceModel: .unknown,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure,
            migrationViewModel: migrationViewModel
        )
    }

    static func createLedgerNotSupportTokenView(
        for tokenName: String,
        cancelClosure: MessageSheetCallback?
    ) -> MessageSheetViewProtocol? {
        let image = R.image.iconLedgerInSheet()

        let mainAction: MessageSheetAction = .okBackAction { cancelClosure?() }

        let title = LocalizableResource { locale in
            R.string.localizable.ledgerNotSupportTokenTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.ledgerNotSupportTokenMessage(
                tokenName,
                tokenName,
                preferredLanguages: locale.rLanguages
            )
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: image,
            content: nil,
            mainAction: mainAction,
            secondaryAction: nil
        )

        let view = MessageSheetViewFactory.createNoContentView(viewModel: viewModel, allowsSwipeDown: false)

        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 335.0)

        return view
    }
}
