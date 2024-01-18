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
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string.localizable.proxySigningMessage(marker, preferredLanguages: locale.rLanguages)

            let decorator = AttributedReplacementStringDecorator(
                pattern: marker,
                replacements: [proxyName],
                attributes: [.foregroundColor: R.color.colorTextPrimary()!]
            )

            return decorator.decorate(attributedString: NSAttributedString(string: template))
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

        view.allowsSwipeDown = false
        view.controller.preferredContentSize = CGSize(width: 0, height: 348)

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view.controller.modalTransitioningFactory = factory
        view.controller.modalPresentationStyle = .custom

        return view
    }

    static func createNotEnoughPermissionsView(
        proxiedName: String,
        proxyName: String,
        type: LocalizableResource<String>,
        completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.proxySigningNotEnoughPermissionsTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string.localizable.proxySigningNotEnoughPermissionsMessage(
                marker,
                marker,
                marker,
                preferredLanguages: locale.rLanguages
            )

            let replacements = [proxiedName, proxyName, type.value(for: locale)]

            let decorator = AttributedReplacementStringDecorator(
                pattern: marker,
                replacements: replacements,
                attributes: [.foregroundColor: R.color.colorTextPrimary()!]
            )

            return decorator.decorate(attributedString: NSAttributedString(string: template))
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageProxy(),
            content: nil,
            mainAction: .okBackAction(for: completionCallback),
            secondaryAction: nil
        )

        let view = MessageSheetViewFactory.createNoContentView(viewModel: viewModel, allowsSwipeDown: false)
        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 284.0)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view?.controller.modalTransitioningFactory = factory
        view?.controller.modalPresentationStyle = .custom

        return view
    }
}
