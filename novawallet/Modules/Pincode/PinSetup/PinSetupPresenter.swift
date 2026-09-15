import Foundation
import NovaAnalytics

class PinSetupPresenter: PinSetupPresenterProtocol {
    weak var view: PinSetupViewProtocol?
    var interactor: PinSetupInteractorInputProtocol!
    var wireframe: PinSetupWireframeProtocol!

    private let abandonTracker: AnalyticsAbandonTracker

    init(isWalletCreation: Bool) {
        abandonTracker = AnalyticsAbandonTracker {
            isWalletCreation ? AnalyticsEvent.walletCreationAbandoned(lastStep: .pinSetup) : nil
        }
    }

    func start() {
        view?.didChangeAccessoryState(enabled: false, availableBiometryType: .none)
    }

    func activateBiometricAuth() {}

    func cancel() {}

    func submit(pin: String) {
        interactor.process(pin: pin)
    }
}

extension PinSetupPresenter: PinSetupInteractorOutputProtocol {
    func didStartWaitingBiometryDecision(
        type: AvailableBiometryType,
        completionBlock: @escaping (Bool) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.view?.didRequestBiometryUsage(biometryType: type, completionBlock: completionBlock)
        }
    }

    func didSavePin() {
        abandonTracker.markProceeded()

        DispatchQueue.main.async { [weak self] in
            self?.wireframe.showMain(from: self?.view)
        }
    }

    func didChangeState(from _: PinSetupInteractor.PinSetupState) {}
}
