import Foundation
import SoraFoundation

class LedgerPerformOperationPresenter: LedgerPerformOperationPresenterProtocol {
    weak var view: LedgerPerformOperationViewProtocol?
    let baseWireframe: LedgerPerformOperationWireframeProtocol
    let baseInteractor: LedgerPerformOperationInputProtocol
    let chainName: String

    private(set) var devices: [LedgerDeviceProtocol] = []

    private(set) var connectingDevice: LedgerDeviceProtocol?

    let localizationManager: LocalizationManagerProtocol

    init(
        chainName: String,
        baseInteractor: LedgerPerformOperationInputProtocol,
        baseWireframe: LedgerPerformOperationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainName = chainName
        self.baseInteractor = baseInteractor
        self.baseWireframe = baseWireframe
        self.localizationManager = localizationManager
    }

    private func updateView() {
        let names = devices.map(\.name)
        view?.didReceive(devices: names)
    }

    func stopConnecting() {
        let identifier = connectingDevice?.identifier
        connectingDevice = nil

        guard let deviceIndex = devices.firstIndex(where: { $0.identifier == identifier }) else {
            return
        }

        view?.didStopLoading(at: deviceIndex)
    }

    func handleAppConnection(error: Error, deviceId: UUID) {
        guard let view = view else {
            return
        }

        if let ledgerError = error as? LedgerError {
            baseWireframe.presentLedgerError(
                on: view,
                error: ledgerError,
                networkName: chainName,
                cancelClosure: {},
                retryClosure: { [weak self] in
                    guard let deviceIndex = self?.devices.firstIndex(where: { $0.identifier == deviceId }) else {
                        return
                    }

                    self?.selectDevice(at: deviceIndex)
                }
            )
        } else {
            _ = baseWireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)
        }
    }

    func handleSetup(error: LedgerDiscoveryError) {
        let locale = localizationManager.selectedLocale

        switch error {
        case .unauthorized:
            baseWireframe.askOpenApplicationSettings(
                with: R.string.localizable.commonBluetoothUnauthorizedMessage(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.commonBluetoothUnauthorizedTitle(preferredLanguages: locale.rLanguages),
                from: view,
                locale: locale
            )
        case .unsupported:
            baseWireframe.present(
                message: R.string.localizable.commonBluetoothUnsupportedMessage(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        case .unknown:
            baseWireframe.present(
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

    // MARK: Protocol

    func setup() {
        view?.didReceive(networkName: chainName)

        baseInteractor.setup()
    }

    func selectDevice(at index: Int) {
        guard connectingDevice == nil else {
            return
        }

        let device = devices[index]
        connectingDevice = device

        view?.didStartLoading(at: index)

        baseInteractor.performOperation(using: device.identifier)
    }
}

extension LedgerPerformOperationPresenter: LedgerPerformOperationOutputProtocol {
    func didDiscover(device: LedgerDeviceProtocol) {
        guard !devices.contains(where: { $0.identifier == device.identifier }) else {
            return
        }

        devices.append(device)
        updateView()
    }

    func didReceiveSetup(error: LedgerDiscoveryError) {
        handleSetup(error: error)
    }
}
