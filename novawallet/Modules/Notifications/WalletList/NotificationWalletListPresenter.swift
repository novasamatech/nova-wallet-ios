import Foundation
import Foundation_iOS
import Operation_iOS

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
    private let walletsLimit: Int = 10

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

    // MARK: - Overrides

    override func setup() {
        super.setup()

        provideTitle()
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
}

// MARK: - Private

private extension NotificationWalletListPresenter {
    func provideTitle() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.notificationsWalletListTitle(walletsLimit)

        view?.setTitle(title)
    }

    func updateViewModels() {
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
        view?.setAction(enabled: !selectedWallets.isEmpty)
    }

    func select(walletId: String) {
        if selectedWallets.count < walletsLimit {
            selectedWallets.insert(walletId)
        } else {
            let title = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.notificationsWalletListLimitErrorTitle(walletsLimit)
            let message = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.notificationsWalletListLimitErrorMessage(walletsLimit)
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

    func deselect(walletId: String) {
        selectedWallets.remove(walletId)

        updateViewModels()
    }
}

// MARK: - NotificationWalletListPresenterProtocol

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

// MARK: - NotificationWalletListInteractorOutputProtocol

extension NotificationWalletListPresenter: NotificationWalletListInteractorOutputProtocol {}
