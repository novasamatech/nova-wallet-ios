import Foundation
import SoraFoundation
import RobinHood

final class NotificationWalletListPresenter: WalletsListPresenter {
    private var selectedWallets: Set<MetaAccountModel.Id> = []

    var view: NotificationWalletListViewProtocol? {
        get {
            baseView as? NotificationWalletListViewProtocol
        }
        set {
            baseView = newValue
        }
    }

    var interactor: NotificationWalletListInteractorInputProtocol? {
        baseInteractor as? NotificationWalletListInteractorInputProtocol
    }

    var wireframe: NotificationWalletListWireframeProtocol? {
        baseWireframe as? NotificationWalletListWireframeProtocol
    }

    let localPushSettingsFactory: PushNotificationSettingsFactoryProtocol

    init(
        initState: [Web3Alert.LocalWallet]?,
        interactor: NotificationWalletListInteractorInputProtocol,
        wireframe: NotificationWalletListWireframeProtocol,
        viewModelFactory: WalletsListViewModelFactoryProtocol,
        localPushSettingsFactory: PushNotificationSettingsFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.localPushSettingsFactory = localPushSettingsFactory
        selectedWallets = Set((initState ?? []).map(\.metaId))

        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func updateWallets(changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        let updatedChanges = filterIgnoredWallet(changes: changes)
        walletsList.apply(changes: updatedChanges)

        if selectedWallets.isEmpty,
           let selectedWallet = walletsList.allItems.first(where: { $0.isSelected }) {
            selectedWallets.insert(selectedWallet.identifier)
        }

        updateViewModels()
    }

    private func updateViewModels() {
        let walletsList = walletsList.allItems.map {
            let isSelected = selectedWallets.contains($0.identifier)
            return ManagedMetaAccountModel(
                info: $0.info,
                isSelected: isSelected,
                order: $0.order
            )
        }
        viewModels = viewModelFactory.createSectionViewModels(
            for: walletsList,
            chains: chains,
            locale: selectedLocale
        )

        view?.didReload()
    }

    private func select(walletId: String) {
        if selectedWallets.count < 3 {
            selectedWallets.insert(walletId)
        } else {
            let title = R.string.localizable.notificationsWalletListLimitErrorTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            let message = R.string.localizable.notificationsWalletListLimitErrorMessage(
                preferredLanguages: selectedLocale.rLanguages
            )
            let closeAction = R.string.localizable.commonCancel()
            wireframe?.present(
                message: message,
                title: title,
                closeAction: closeAction,
                from: view
            )
        }

        updateViewModels()
    }

    private func deselect(walletId: String) {
        guard selectedWallets.count > 1 else {
            return
        }

        selectedWallets.remove(walletId)

        updateViewModels()
    }
}

extension NotificationWalletListPresenter: NotificationWalletListPresenterProtocol {
    func selectItem(at index: Int, section: Int) {
        let identifier = viewModels[section].items[index].identifier

        if selectedWallets.contains(identifier) {
            deselect(walletId: identifier)
        } else {
            select(walletId: identifier)
        }
    }

    func confirm() {
        let wallets = walletsList.allItems
            .filter {
                selectedWallets.contains($0.identifier)
            }
            .map {
                localPushSettingsFactory.createWallet(from: $0.info, chains: chains)
            }

        wireframe?.complete(from: view, selectedWallets: wallets)
    }
}

extension NotificationWalletListPresenter: NotificationWalletListInteractorOutputProtocol {}
