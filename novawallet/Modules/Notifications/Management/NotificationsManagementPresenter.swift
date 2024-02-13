import Foundation
import SoraFoundation

final class NotificationsManagementPresenter {
    weak var view: NotificationsManagementViewProtocol?
    let wireframe: NotificationsManagementWireframeProtocol
    let interactor: NotificationsManagementInteractorInputProtocol
    let viewModelFactory: NotificationsManagemenViewModelFactoryProtocol

    private var notificationsEnabled: Bool = true
    private var selectedWallets: [MetaAccountModel] = []
    private var announcementsEnabled: Bool = true
    private var sentTokensEnabled: Bool = true
    private var receiveTokensEnabled: Bool = true
    private var govEnabled: Bool = true
    private var stakingRewardsEnabled: Bool = true

    init(
        interactor: NotificationsManagementInteractorInputProtocol,
        wireframe: NotificationsManagementWireframeProtocol,
        viewModelFactory: NotificationsManagemenViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    func getParameters() -> NotificationsManagementParameters? {
        .init(
            isNotificationsOn: notificationsEnabled,
            wallets: selectedWallets.count,
            isAnnouncementsOn: announcementsEnabled,
            isSentTokensOn: sentTokensEnabled,
            isReceiveTokensOn: receiveTokensEnabled,
            isGovernanceOn: govEnabled,
            isStakingOn: stakingRewardsEnabled
        )
    }

    func updateView() {
        guard let parameters = getParameters() else {
            return
        }
        let viewModel = viewModelFactory.createSectionViewModels(
            parameters: parameters,
            locale: selectedLocale
        )
        view?.didReceive(sections: viewModel)
    }
}

extension NotificationsManagementPresenter: NotificationsManagementPresenterProtocol {
    func setup() {
        updateView()
    }

    func actionRow(_ row: NotificationsManagementRow) {
        switch row {
        case .enableNotifications:
            notificationsEnabled.toggle()
            updateView()
        case .announcements:
            announcementsEnabled.toggle()
            updateView()
        case .sentTokens:
            sentTokensEnabled.toggle()
            updateView()
        case .receivedTokens:
            receiveTokensEnabled.toggle()
            updateView()
        case .wallets:
            wireframe.showWallets(from: view)
        case .gov:
            wireframe.showGovSetup(from: view)
        case .staking:
            wireframe.showStakingRewardsSetup(from: view)
        }
    }

    func save() {}
}

extension NotificationsManagementPresenter: NotificationsManagementInteractorOutputProtocol {}

extension NotificationsManagementPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
