import Foundation
import Foundation_iOS

final class MultisigNotificationsPresenter {
    weak var view: MultisigNotificationsViewProtocol?

    let interactor: MultisigNotificationsInteractorInputProtocol
    let wireframe: MultisigNotificationsWireframeProtocol
    let localizationManager: LocalizationManagerProtocol
    let selectedMetaIds: Set<MetaAccountModel.Id>

    var multisigWallets: [MetaAccountModel]?

    private var settings: MultisigNotificationsModel {
        didSet { enabled = settings.isEnabled }
    }

    private var enabled: Bool {
        didSet {
            guard oldValue != enabled else { return }
            provideViewModel()
        }
    }

    init(
        interactor: MultisigNotificationsInteractorInputProtocol,
        wireframe: MultisigNotificationsWireframeProtocol,
        settings: MultisigNotificationsModel,
        selectedMetaIds: Set<MetaAccountModel.Id>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.settings = settings
        self.selectedMetaIds = selectedMetaIds
        self.localizationManager = localizationManager
        enabled = settings.isEnabled
    }
}

// MARK: - Private

private extension MultisigNotificationsPresenter {
    func provideViewModel() {
        let enableModel = SwitchTitleIconViewModel(
            title: R.string.localizable.notificationsManagementEnableNotifications(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ),
            icon: nil,
            isOn: settings.isEnabled,
            action: actionEnableNotifications
        )
        let signatureRequestedModel = SwitchTitleIconViewModel(
            title: R.string.localizable.notificationsManagementMultisigSignatureRequested(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ),
            icon: nil,
            isOn: settings.signatureRequested,
            action: actionSignatureRequested
        )
        let signedBySignatoryModel = SwitchTitleIconViewModel(
            title: R.string.localizable.notificationsManagementMultisigSignedBySignatory(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ),
            icon: nil,
            isOn: settings.signedBySignatory,
            action: actionSignedBySignatory
        )
        let signedTransactionExecutedModel = SwitchTitleIconViewModel(
            title: R.string.localizable.notificationsManagementMultisigTransactionExecuted(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ),
            icon: nil,
            isOn: settings.transactionExecuted,
            action: actionTransactionExecuted
        )
        let signedTransactionRejectedModel = SwitchTitleIconViewModel(
            title: R.string.localizable.notificationsManagementMultisigTransactionRejected(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ),
            icon: nil,
            isOn: settings.transactionRejected,
            action: actionTransactionRejected
        )

        let viewModel = MultisigNotificationsViewModel(
            switchModels: [
                enableModel,
                signatureRequestedModel,
                signedBySignatoryModel,
                signedTransactionExecutedModel,
                signedTransactionRejectedModel
            ]
        )

        view?.didReceive(viewModel: viewModel)
    }

    func actionEnableNotifications(_ selected: Bool) {
        guard
            let multisigWallets,
            !multisigWallets.isEmpty,
            !selectedMetaIds.isDisjoint(with: multisigWallets.map(\.metaId))
        else {
            settings = .empty()
            provideViewModel()
            showNoMultisigWalletsAlert()
            return
        }

        settings.signatureRequested = selected
        settings.signedBySignatory = selected
        settings.transactionExecuted = selected
        settings.transactionRejected = selected

        provideViewModel()
    }

    func actionSignatureRequested(_ selected: Bool) {
        settings.signatureRequested = selected
    }

    func actionSignedBySignatory(_ selected: Bool) {
        settings.signedBySignatory = selected
    }

    func actionTransactionExecuted(_ selected: Bool) {
        settings.transactionExecuted = selected
    }

    func actionTransactionRejected(_ selected: Bool) {
        settings.transactionRejected = selected
    }

    func showNoMultisigWalletsAlert() {
        let title = R.string.localizable.notificationsManagementMultisigNoWalletsAlertTitle(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let message = R.string.localizable.notificationsManagementMultisigNoWalletsAlertMessage(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let learnMoreActionTitle = R.string.localizable.commonLearnMore(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )
        let gotItActionTitle = R.string.localizable.commonGotIt(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        )

        let actions = [
            AlertPresentableAction(
                title: learnMoreActionTitle,
                style: .normal,
                handler: { [weak self] in self?.wireframe.showLearnMore(from: self?.view) }
            ),
            AlertPresentableAction(
                title: gotItActionTitle,
                style: .cancel,
                handler: {}
            )
        ]

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: actions,
            closeAction: nil
        )

        wireframe.present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }
}

// MARK: - MultisigNotificationsPresenterProtocol

extension MultisigNotificationsPresenter: MultisigNotificationsPresenterProtocol {
    func proceed() {
        wireframe.complete(settings: settings)
    }

    func setup() {
        interactor.setup()
    }
}

// MARK: - MultisigNotificationsInteractorOutputProtocol

extension MultisigNotificationsPresenter: MultisigNotificationsInteractorOutputProtocol {
    func didReceive(multisigWallets: [MetaAccountModel]) {
        self.multisigWallets = multisigWallets

        provideViewModel()
    }
}
