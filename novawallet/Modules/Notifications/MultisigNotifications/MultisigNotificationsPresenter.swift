import Foundation
import Foundation_iOS

final class MultisigNotificationsPresenter {
    weak var view: MultisigNotificationsViewProtocol?
    let wireframe: MultisigNotificationsWireframeProtocol
    let localizationManager: LocalizationManagerProtocol

    private var settings: MultisigNotificationsModel

    init(
        wireframe: MultisigNotificationsWireframeProtocol,
        settings: MultisigNotificationsModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.settings = settings
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension MultisigNotificationsPresenter {
    func provideViewModel() {
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
                signatureRequestedModel,
                signedBySignatoryModel,
                signedTransactionExecutedModel,
                signedTransactionRejectedModel
            ]
        )

        view?.didReceive(viewModel: viewModel)
    }

    func actionSignatureRequested(_ selected: Bool) {
        settings.signatureRequested = selected

        provideViewModel()
    }

    func actionSignedBySignatory(_ selected: Bool) {
        settings.signedBySignatory = selected

        provideViewModel()
    }

    func actionTransactionExecuted(_ selected: Bool) {
        settings.transactionExecuted = selected

        provideViewModel()
    }

    func actionTransactionRejected(_ selected: Bool) {
        settings.transactionRejected = selected

        provideViewModel()
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

    func clear() {
        settings.signatureRequested = false
        settings.signedBySignatory = false
        settings.transactionExecuted = false
        settings.transactionRejected = false
    }
}
