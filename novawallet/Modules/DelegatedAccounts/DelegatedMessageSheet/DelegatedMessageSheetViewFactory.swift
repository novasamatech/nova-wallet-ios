import Foundation
import Foundation_iOS
import Keystore_iOS
import UIKit_iOS
import UIKit

enum DelegatedMessageSheetViewFactory {
    static func createSigningView(
        delegatedId: MetaAccountModel.Id,
        delegateChainAccountResponse: ChainAccountResponse,
        delegationClass: DelegationClass,
        completionClosure: @escaping MessageSheetCallback,
        cancelClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let repositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let repository = repositoryFactory.createDelegatedAccountSettingsRepository()

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

        let sheetContent = switch delegationClass {
        case .proxy:
            createProxyContent(proxyName: delegateChainAccountResponse.name)
        case .multisig:
            createMultisigContent(signatoryName: delegateChainAccountResponse.name)
        }

        let text = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.delegatedSigningCheckmarkTitle()
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
        view.controller.preferredContentSize = CGSize(width: 0, height: 358)

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
            R.string(preferredLanguages: locale.rLanguages).localizable.proxySigningNotEnoughPermissionsTitle()
        }

        let message = LocalizableResource { locale in
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.proxySigningNotEnoughPermissionsMessage(
                marker,
                marker,
                marker
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
        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 294.0)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view?.controller.modalTransitioningFactory = factory
        view?.controller.modalPresentationStyle = .custom

        return view
    }

    static func createMultisigOpCreated(
        viewDetailsCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.multisigTransactionCreatedSheetTitle()
        }

        let message = LocalizableResource { locale in
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.multisigTransactionCreatedSheetMessage(
                marker
            )

            let replacement = R.string(preferredLanguages: locale.rLanguages).localizable.multisigTransactionsToSign()

            let decorator = AttributedReplacementStringDecorator(
                pattern: marker,
                replacements: [replacement],
                attributes: [.foregroundColor: R.color.colorTextPrimary()!]
            )

            return decorator.decorate(attributedString: NSAttributedString(string: template))
        }

        let viewDetailsAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonViewDetails()
            },
            handler: viewDetailsCallback
        )

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageMultisig(),
            content: nil,
            mainAction: viewDetailsAction,
            secondaryAction: .cancelAction(for: {})
        )

        let view = MessageSheetViewFactory.createNoContentView(viewModel: viewModel, allowsSwipeDown: true)
        view?.controller.preferredContentSize = CGSize(width: 0.0, height: 312.0)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view?.controller.modalTransitioningFactory = factory
        view?.controller.modalPresentationStyle = .custom

        return view
    }

    static func createMultisigRejectView(
        multisigAccountId: MetaAccountModel.Id,
        depositorAccount: MetaChainAccountResponse,
        completionClosure: @escaping MessageSheetCallback,
        cancelClosure: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let repositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let repository = repositoryFactory.createDelegatedAccountSettingsRepository()

        let interactor = DelegatedMessageSheetInteractor(
            metaId: multisigAccountId,
            repository: repository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let presenter = DelegatedMessageSheetPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let sheetContent = createMultisigRejectContent(depositorName: depositorAccount.chainAccount.name)

        let text = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.delegatedSigningCheckmarkTitle()
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
        view.controller.preferredContentSize = CGSize(width: 0, height: 358)

        presenter.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        view.controller.modalTransitioningFactory = factory
        view.controller.modalPresentationStyle = .custom

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
            R.string(preferredLanguages: locale.rLanguages).localizable.proxySigningTitle()
        }

        let message = LocalizableResource { locale in
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string(preferredLanguages: locale.rLanguages).localizable.proxySigningMessage(marker)

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
            R.string(preferredLanguages: locale.rLanguages).localizable.multisigSigningTitle()
        }

        let message = LocalizableResource { locale in
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string(preferredLanguages: locale.rLanguages).localizable.multisigSigningMessage(
                marker
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

    static func createMultisigRejectContent(depositorName: String?) -> MessageSheetContent {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.multisigSigningTitle()
        }

        let message = LocalizableResource { locale in
            let marker = AttributedReplacementStringDecorator.marker
            let template = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.multisigTransactionRejectSheetMessage(
                marker
            )

            let decorator = AttributedReplacementStringDecorator(
                pattern: marker,
                replacements: [depositorName].compactMap { $0 },
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
