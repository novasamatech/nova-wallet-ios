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
            R.string(preferredLanguages: locale.rLanguages).localizable.noKeyTitle()
        }

        let message = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.noKeyMessage()
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
        case .sell where walletType == .proxied:
            title = LocalizableResource<String> { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetTitleSellProxied()
            }
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetMessageSellProxied()
            }
        case .card where walletType == .proxied:
            title = LocalizableResource<String> { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetTitleCardProxied()
            }
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetMessageCard()
            }
        case .sell:
            title = LocalizableResource<String> { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetTitleSell(
                    walletType.description(for: locale).capitalized
                )
            }
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetMessageSell()
            }
        case .card:
            title = LocalizableResource<String> { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetTitleCard(
                    walletType.description(for: locale).capitalized
                )
            }
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.featureUnsupportedSheetMessageCard()
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
            R.string(preferredLanguages: locale.rLanguages).localizable.commonSigningNotSupportedTitle()
        }

        let icon: UIImage?
        let message: LocalizableResource<String>

        switch type {
        case .paritySigner:
            icon = R.image.iconParitySignerInSheet()
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonParitySignerNotSupportedMessage(
                    ParitySignerType.legacy.getName(for: locale)
                )
            }
        case .polkadotVault:
            icon = R.image.iconPolkadotVaultInSheet()
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonParitySignerNotSupportedMessage(
                    ParitySignerType.vault.getName(for: locale)
                )
            }
        case .ledger:
            icon = R.image.iconLedgerInSheet()
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.commonLedgerNotSupportedMessage()
            }
        case .proxy:
            icon = R.image.imageProxy()
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.proxySigningIsNotSupportedMessage()
            }
        case .multisig:
            icon = R.image.imageMultisig()
            message = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.multisigSigningIsNotSupportedMessage()
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
