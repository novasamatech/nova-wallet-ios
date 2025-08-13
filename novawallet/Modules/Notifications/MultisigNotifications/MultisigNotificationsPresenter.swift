import Foundation
import Foundation_iOS

final class MultisigNotificationsPresenter {
    weak var view: MultisigNotificationsViewProtocol?
    let wireframe: MultisigNotificationsWireframeProtocol
    let localizationManager: LocalizationManagerProtocol

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
        wireframe: MultisigNotificationsWireframeProtocol,
        settings: MultisigNotificationsModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.settings = settings
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
}

// MARK: - MultisigNotificationsPresenterProtocol

extension MultisigNotificationsPresenter: MultisigNotificationsPresenterProtocol {
    func proceed() {
        wireframe.complete(settings: settings)
    }

    func setup() {
        provideViewModel()
    }
}
