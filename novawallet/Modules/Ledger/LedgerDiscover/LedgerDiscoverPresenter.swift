import Foundation

final class LedgerDiscoverPresenter {
    weak var view: LedgerDiscoverViewProtocol?
    let wireframe: LedgerDiscoverWireframeProtocol
    let interactor: LedgerDiscoverInteractorInputProtocol

    private var devices: [LedgerDeviceProtocol] = []

    init(
        interactor: LedgerDiscoverInteractorInputProtocol,
        wireframe: LedgerDiscoverWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    private func updateView() {
        let names = devices.map(\.name)
        view?.didReceive(devices: names)
    }
}

extension LedgerDiscoverPresenter: LedgerDiscoverPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectDevice(at index: Int) {
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
}
