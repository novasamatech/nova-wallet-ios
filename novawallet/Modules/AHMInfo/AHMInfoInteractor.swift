import Foundation

final class AHMInfoInteractor {
    weak var presenter: AHMInfoInteractorOutputProtocol?

    private let remoteData: AHMRemoteData
    private let chainRegistry: ChainRegistryProtocol

    init(
        remoteData: AHMRemoteData,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.remoteData = remoteData
        self.chainRegistry = chainRegistry
    }
}

// MARK: - AHMInfoInteractorInputProtocol

extension AHMInfoInteractor: AHMInfoInteractorInputProtocol {
    func setup() {
        if let sourceChain = chainRegistry.getChain(for: remoteData.sourceData.chainId) {
            presenter?.didReceive(sourceChain: sourceChain)
        }

        if let destinationChain = chainRegistry.getChain(for: remoteData.destinationData.chainId) {
            presenter?.didReceive(destinationChain: destinationChain)
        }
    }
}
