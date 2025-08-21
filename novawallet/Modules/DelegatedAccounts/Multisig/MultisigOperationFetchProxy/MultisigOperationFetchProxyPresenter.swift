import Foundation
import Foundation_iOS

final class MultisigOperationFetchProxyPresenter {
    weak var view: MultisigOperationFetchProxyViewProtocol?

    let wireframe: MultisigOperationFetchProxyWireframeProtocol
    let interactor: MultisigOperationFetchProxyInteractorInputProtocol

    let localizationManager: LocalizationManagerProtocol

    init(
        wireframe: MultisigOperationFetchProxyWireframeProtocol,
        interactor: MultisigOperationFetchProxyInteractorInputProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension MultisigOperationFetchProxyPresenter {
    func showConfirmation(for operation: Multisig.PendingOperationProxyModel) {
        view?.didReceive(loading: false)

        let flowState = interactor.createFlowState()

        wireframe.showConfirmationData(
            from: view,
            for: operation,
            flowState: flowState
        )
    }

    func showConfirmationEnded() {
        let languages = localizationManager.selectedLocale.rLanguages

        let title = R.string.localizable.multisigOperationEndedAlertTitle(
            preferredLanguages: languages
        )
        let message = R.string.localizable.multisigOperationEndedAlertMessage(
            preferredLanguages: languages
        )
        let actionTitle = R.string.localizable.commonGotIt(preferredLanguages: languages)
        let action = AlertPresentableAction(title: actionTitle) { [weak self] in
            self?.wireframe.close(from: self?.view)
        }

        let alertViewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [action],
            closeAction: nil
        )

        wireframe.present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }

    func showError(_ error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}

// MARK: - MultisigOperationFetchProxyPresenterProtocol

extension MultisigOperationFetchProxyPresenter: MultisigOperationFetchProxyPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

// MARK: - MultisigOperationFetchProxyInteractorOutputProtocol

extension MultisigOperationFetchProxyPresenter: MultisigOperationFetchProxyInteractorOutputProtocol {
    func didReceiveError(_ error: MultisigOperationFetchProxyError) {
        switch error {
        case .onChainOperationNotFound:
            showConfirmationEnded()
        case let .common(commonError):
            showError(commonError)
        }
    }

    func didReceiveOperation(_ operation: Multisig.PendingOperationProxyModel?) {
        guard let operation else {
            view?.didReceive(loading: true)
            return
        }

        showConfirmation(for: operation)
    }
}
