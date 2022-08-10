import Foundation
import SoraFoundation

struct MessageSheetViewFactory {
    static func createNoSigningView(with completionCallback: @escaping () -> Void) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe(completionCallback: completionCallback)

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.noKeyTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.noKeyMessage(preferredLanguages: locale.rLanguages)
        }

        let viewModel = MessageSheetViewModel(
            title: title,
            message: message,
            icon: R.image.imageNoKeys()
        )

        let view = MessageSheetViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)

        presenter.view = view

        return view
    }

    static func createParitySignerNotSupportedView(
        with completionCallback: @escaping () -> Void
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe(completionCallback: completionCallback)

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.commonSigningNotSupportedTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.commonParitySignerNotSupportedMessage(preferredLanguages: locale.rLanguages)
        }

        let viewModel = MessageSheetViewModel(
            title: title,
            message: message,
            icon: R.image.iconParitySignerInSheet()
        )

        let view = MessageSheetViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)

        presenter.view = view

        return view
    }
}
