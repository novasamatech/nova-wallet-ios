import Foundation
import Foundation_iOS
import Keystore_iOS
import UIKit_iOS

enum DelegatedMessageSheetViewFactory {
    static func createSigningView(
        delegatedId: MetaAccountModel.Id,
        delegateChainAccountResponse: ChainAccountResponse,
        delegationType: DelegationType,
        completionClosure: @escaping MessageSheetCallback,
        cancelClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let repositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let repository = repositoryFactory.createProxiedSettingsRepository()

        let interactor = DelegatedMessageSheetInteractor(
            metaId: delegatedId,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let presenter = DelegatedMessageSheetPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let sheetContent = switch delegationType {
        case .proxy:
            createProxyContent(proxyName: delegateChainAccountResponse.name)
        case .multisig:
            createMultisigContent(signatoryName: delegateChainAccountResponse.name)
        }

        let text = LocalizableResource { locale in
            R.string.localizable.delegatedSigningCheckmarkTitle(
                preferredLanguages: locale.rLanguages
            )
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetCheckmarkContentViewModel>(
            title: sheetContent.title,
            message: sheetContent.message,
            graphics: sheetContent.graphics,
            content: MessageSheetCheckmarkContentViewModel(checked: false, text: text),
            mainAction: .continueAction(for: completionClosure),
            secondaryAction: .cancelAction(for: cancelClosure)
        )

        let view = DelegatedMessageSheetViewController(
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

private extension DelegatedMessageSheetViewFactory {
    struct MessageSheetContent {
        let title: LocalizableResource<String>
        let message: LocalizableResource<NSAttributedString>
        let graphics: UIImage?
    }

    static func createProxyContent(proxyName: String) -> MessageSheetContent {
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

        return MessageSheetContent(
            title: title,
            message: message,
            graphics: R.image.imageProxy()
        )
    }

    static func createMultisigContent(signatoryName: String) -> MessageSheetContent {
        let title = LocalizableResource { locale in
            R.string.localizable.multisigSigningTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string.localizable.multisigSigningMessage(
                marker,
                preferredLanguages: locale.rLanguages
            )

            let decorator = AttributedReplacementStringDecorator(
                pattern: marker,
                replacements: [signatoryName],
                attributes: [.foregroundColor: R.color.colorTextPrimary()!]
            )

            return decorator.decorate(attributedString: NSAttributedString(string: template))
        }

        return MessageSheetContent(
            title: title,
            message: message,
            graphics: R.image.imageMultisig()
        )
    }
}
