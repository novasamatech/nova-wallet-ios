import Foundation
import SoraFoundation
import UIKit

struct MessageSheetViewFactory {
    static func createNoSigningView(
        with completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe(completionCallback: completionCallback)

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.noKeyTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.noKeyMessage(preferredLanguages: locale.rLanguages)
        }

        let viewModel = MessageSheetViewModel<UIImage>(
            title: title,
            message: message,
            graphics: R.image.imageNoKeys(),
            hasAction: true
        )

        let view = MessageSheetViewController<MessageSheetImageView, UIImage>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)

        presenter.view = view

        return view
    }

    static func createParitySignerNotSupportedView(
        with completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe(completionCallback: completionCallback)

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.commonSigningNotSupportedTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.commonParitySignerNotSupportedMessage(preferredLanguages: locale.rLanguages)
        }

        let viewModel = MessageSheetViewModel<UIImage>(
            title: title,
            message: message,
            graphics: R.image.iconParitySignerInSheet(),
            hasAction: true
        )

        let view = MessageSheetViewController<MessageSheetImageView, UIImage>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)

        presenter.view = view

        return view
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

        let graphicsViewModel = MessageSheetLedgerViewModel(
            backgroundImage: R.image.graphicsLedgerVerify()!,
            text: title,
            icon: R.image.iconEye14()!,
            infoRenderSize: CGSize(width: 100.0, height: 72.0)
        )

        let viewModel = MessageSheetViewModel<MessageSheetLedgerViewModel>(
            title: title,
            message: message,
            graphics: graphicsViewModel,
            hasAction: false
        )

        let view = MessageSheetViewController<MessageSheetLedgerView, MessageSheetLedgerViewModel>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 365.0)

        presenter.view = view

        return view
    }
}
