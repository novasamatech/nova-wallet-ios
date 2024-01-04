import Foundation
import SoraFoundation
import SoraKeystore
import SoraUI

enum ProxyMessageSheetViewFactory {
    static func createSigningView(
        proxyName: String,
        completionClosure: @escaping MessageSheetCallback,
        cancelClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = ProxyMessageSheetPresenter(
            settings: SettingsManager.shared,
            wireframe: wireframe
        )

        let title = LocalizableResource { locale in
            R.string.localizable.proxySigningTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.proxySigningMessage(proxyName, preferredLanguages: locale.rLanguages)
        }

        let text = LocalizableResource { locale in
            R.string.localizable.proxySigningCheckmarkTitle(
                preferredLanguages: locale.rLanguages
            )
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetCheckmarkContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageProxy(),
            content: MessageSheetCheckmarkContentViewModel(checked: false, text: text),
            mainAction: .continueAction(for: completionClosure),
            secondaryAction: .cancelAction(for: cancelClosure)
        )

        let view = ProxyMessageSheetViewController(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0, height: 348)

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view.controller.modalTransitioningFactory = factory
        view.controller.modalPresentationStyle = .custom

        return view
    }

    static func createNoSigningView(
        with completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.proxySigningIsNotSupportedTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.proxySigningIsNotSupportedMessage(preferredLanguages: locale.rLanguages)
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageProxy(),
            content: nil,
            mainAction: .okBackAction(for: completionCallback),
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetNoContentView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 284.0)

        presenter.view = view

        return view
    }

    static func createNotEnoughPermissionsView(
        proxiedName: String,
        proxyName: String,
        type: LocalizableResource<String>,
        completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.proxySigningNotEnoughPermissionsTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.proxySigningNotEnoughPermissionsMessage(
                proxiedName,
                proxyName,
                type.value(for: locale),
                preferredLanguages: locale.rLanguages
            )
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageProxy(),
            content: nil,
            mainAction: .okBackAction(for: completionCallback),
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetNoContentView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 284.0)

        presenter.view = view

        return view
    }
}
