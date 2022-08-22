import Foundation
import SoraFoundation

final class LedgerDiscoverPresenter {
    weak var view: LedgerDiscoverViewProtocol?
    let wireframe: LedgerDiscoverWireframeProtocol
    let interactor: LedgerDiscoverInteractorInputProtocol

    private var devices: [LedgerDeviceProtocol] = []

    private var isConnecting: Bool = false

    let localizationManager: LocalizationManagerProtocol

    // TODO: Provide user selected network
    let networkName: String = "Polkadot"

    init(
        interactor: LedgerDiscoverInteractorInputProtocol,
        wireframe: LedgerDiscoverWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let names = devices.map(\.name)
        view?.didReceive(devices: names)
    }

    private func stopConnecting(to deviceId: UUID) {
        guard isConnecting else {
            return
        }

        isConnecting = false

        guard let deviceIndex = devices.firstIndex(where: { $0.identifier == deviceId }) else {
            return
        }

        view?.didStopLoading(at: deviceIndex)
    }

    private func handleAppConnection(error: Error, deviceId: UUID) {
        guard let view = view else {
            return
        }

        if let ledgerError = error as? LedgerError {
            wireframe.presentLedgerError(
                on: view,
                error: ledgerError,
                networkName: networkName,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                guard let deviceIndex = self?.devices.firstIndex(where: { $0.identifier == deviceId }) else {
                    return
                }

                self?.selectDevice(at: deviceIndex)
            }
        } else {
            _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)
        }
    }

    private func handleSetup(error: LedgerDiscoveryError) {
        let locale = localizationManager.selectedLocale

        switch error {
        case .unauthorized:
            wireframe.askOpenApplicationSettings(
                with: R.string.localizable.commonBluetoothUnauthorizedMessage(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.commonBluetoothUnauthorizedTitle(preferredLanguages: locale.rLanguages),
                from: view,
                locale: locale
            )
        case .unsupported:
            wireframe.present(
                message: R.string.localizable.commonBluetoothUnsupportedMessage(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        case .unknown:
            wireframe.present(
                message: R.string.localizable.commonBluetoothUnknownMessage(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        case .unavailable:
            // we rely on the native alert to navigate to Bluetooth settings
            break
        }
    }
}

extension LedgerDiscoverPresenter: LedgerDiscoverPresenterProtocol {
    func setup() {
        view?.didReceive(networkName: networkName)

        interactor.setup()
    }

    func selectDevice(at index: Int) {
        guard !isConnecting else {
            return
        }

        isConnecting = true

        view?.didStartLoading(at: index)

        interactor.connect(to: devices[index].identifier)
    }
}

extension LedgerDiscoverPresenter: LedgerDiscoverInteractorOutputProtocol {
    func didDiscover(device: LedgerDeviceProtocol) {
        guard !devices.contains(where: { $0.identifier == device.identifier }) else {
            return
        }

        devices.append(device)
        updateView()
    }

    func didReceiveConnection(result: Result<Void, Error>, for deviceId: UUID) {
        stopConnecting(to: deviceId)

        switch result {
        case .success:
            wireframe.showAccountSelection(from: view, for: deviceId)
        case let .failure(error):
            handleAppConnection(error: error, deviceId: deviceId)
        }
    }

    func didReceiveSetup(error: LedgerDiscoveryError) {
        handleSetup(error: error)
    }
}
