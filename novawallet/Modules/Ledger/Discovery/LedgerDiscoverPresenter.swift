import Foundation
import Foundation_iOS

final class LedgerDiscoverPresenter: LedgerPerformOperationPresenter {
    var wireframe: LedgerDiscoverWireframeProtocol? {
        baseWireframe as? LedgerDiscoverWireframeProtocol
    }

    init(
        appName: String,
        interactor: LedgerPerformOperationInputProtocol,
        wireframe: LedgerPerformOperationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(
            appName: appName,
            baseInteractor: interactor,
            baseWireframe: wireframe,
            localizationManager: localizationManager
        )
    }
}

extension LedgerDiscoverPresenter: LedgerDiscoverInteractorOutputProtocol {
    func didReceiveConnection(result: Result<Void, Error>, for deviceId: UUID) {
        stopConnecting()

        switch result {
        case .success:
            guard let device = devices.first(where: { $0.identifier == deviceId }) else {
                return
            }

            wireframe?.showAccountSelection(from: view, device: device)
        case let .failure(error):
            handleAppConnection(error: error, deviceId: deviceId)
        }
    }
}
