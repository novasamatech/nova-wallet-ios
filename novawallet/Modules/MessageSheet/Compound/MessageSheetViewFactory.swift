import Foundation
import Foundation_iOS
import UIKit
import Keystore_iOS

struct MessageSheetViewFactory {
    static func createNoSigningView(
        with completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.noKeyTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            R.string.localizable.noKeyMessage(preferredLanguages: locale.rLanguages)
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: R.image.imageNoKeys(),
            content: nil,
            mainAction: .okBackAction(for: completionCallback),
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetNoContentView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)

        presenter.view = view

        return view
    }

    static func createFeatureNotSupportedView(
        type: UnsupportedFeatureType,
        walletType: FeatureUnsupportedWalletType,
        completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title: LocalizableResource<String>
        let message: LocalizableResource<String>

        switch type {
        case .sell:
            title = LocalizableResource<String> { locale in
                R.string.localizable.featureUnsupportedSheetTitleSell(
                    walletType.description(for: locale).capitalized,
                    preferredLanguages: locale.rLanguages
                )
            }
            message = LocalizableResource { locale in
                R.string.localizable.featureUnsupportedSheetMessageSell(
                    preferredLanguages: locale.rLanguages
                )
            }
        case .card:
            title = LocalizableResource<String> { locale in
                R.string.localizable.featureUnsupportedSheetTitleCard(
                    walletType.description(for: locale).capitalized,
                    preferredLanguages: locale.rLanguages
                )
            }
            message = LocalizableResource { locale in
                R.string.localizable.featureUnsupportedSheetMessageCard(
                    preferredLanguages: locale.rLanguages
                )
            }
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: walletType.sheetImage(),
            content: nil,
            mainAction: .okBackAction(for: completionCallback),
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetNoContentView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)

        presenter.view = view

        return view
    }

    static func createSignerNotSupportedView(
        type: NoSigningSupportType,
        completionCallback: @escaping MessageSheetCallback
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let title = LocalizableResource { locale in
            R.string.localizable.commonSigningNotSupportedTitle(preferredLanguages: locale.rLanguages)
        }

        let icon: UIImage?
        let message: LocalizableResource<String>

        switch type {
        case .paritySigner:
            icon = R.image.iconParitySignerInSheet()
            message = LocalizableResource { locale in
                R.string.localizable.commonParitySignerNotSupportedMessage(
                    ParitySignerType.legacy.getName(for: locale),
                    preferredLanguages: locale.rLanguages
                )
            }
        case .polkadotVault:
            icon = R.image.iconPolkadotVaultInSheet()
            message = LocalizableResource { locale in
                R.string.localizable.commonParitySignerNotSupportedMessage(
                    ParitySignerType.vault.getName(for: locale),
                    preferredLanguages: locale.rLanguages
                )
            }
        case .ledger:
            icon = R.image.iconLedgerInSheet()
            message = LocalizableResource { locale in
                R.string.localizable.commonLedgerNotSupportedMessage(preferredLanguages: locale.rLanguages)
            }
        case .proxy:
            icon = R.image.imageProxy()
            message = LocalizableResource { locale in
                R.string.localizable.proxySigningIsNotSupportedMessage(preferredLanguages: locale.rLanguages)
            }
        case .multisig:
            icon = R.image.imageMultisig()
            message = LocalizableResource { locale in
                R.string.localizable.multisigSigningIsNotSupportedMessage(preferredLanguages: locale.rLanguages)
            }
        }

        let viewModel = MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>(
            title: title,
            message: message,
            graphics: icon,
            content: nil,
            mainAction: .okBackAction(for: completionCallback),
            secondaryAction: nil
        )

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetNoContentView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)

        presenter.view = view

        return view
    }

    static func createNoContentView(
        viewModel: MessageSheetViewModel<UIImage, MessageSheetNoContentViewModel>,
        allowsSwipeDown: Bool
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetNoContentView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 300.0)
        view.allowsSwipeDown = allowsSwipeDown

        presenter.view = view

        return view
    }

    static func createMigrationBannerContentView(
        viewModel: MessageSheetViewModel<UIImage, MessageSheetMigrationBannerView.ContentViewModel>,
        allowsSwipeDown: Bool
    ) -> MessageSheetViewProtocol? {
        let wireframe = MessageSheetWireframe()

        let presenter = MessageSheetPresenter(wireframe: wireframe)

        let view = MessageSheetViewController<MessageSheetImageView, MessageSheetMigrationBannerView>(
            presenter: presenter,
            viewModel: viewModel,
            localizationManager: LocalizationManager.shared
        )

        view.controller.preferredContentSize = CGSize(width: 0.0, height: 534.0)
        view.allowsSwipeDown = allowsSwipeDown

        presenter.view = view

        return view
    }
}
