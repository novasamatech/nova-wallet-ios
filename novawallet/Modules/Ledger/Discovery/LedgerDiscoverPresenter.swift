import Foundation
import SoraFoundation

final class LedgerDiscoverPresenter: LedgerPerformOperationPresenter {
    var wireframe: LedgerDiscoverWireframeProtocol? {
        baseWireframe as? LedgerDiscoverWireframeProtocol
    }

    let chain: ChainModel

    init(
        chain: ChainModel,
        interactor: LedgerPerformOperationInputProtocol,
        wireframe: LedgerPerformOperationWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chain = chain

        super.init(
            chainName: chain.name,
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

            wireframe?.showAccountSelection(from: view, chain: chain, device: device)
        case let .failure(error):
            handleAppConnection(error: error, deviceId: deviceId)
        }
    }
}
