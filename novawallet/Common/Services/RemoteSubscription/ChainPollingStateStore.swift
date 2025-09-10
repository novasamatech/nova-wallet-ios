import Foundation

struct ChainPollingState: Equatable {
    typealias TChange = BatchSubscriptionHandler

    let blockHash: BlockHashData?
}

extension ChainPollingState: ObservableSubscriptionStateProtocol {
    init(change: TChange) throws {
        blockHash = change.blockHash
    }

    func merging(change: TChange) -> Self {
        ChainPollingState(blockHash: change.blockHash)
    }
}

protocol ChainPollingStateStoring: BaseObservableStateStoreProtocol where RemoteState == ChainPollingState {}

final class ChainPollingStateStore: ObservableSubscriptionStateStore<ChainPollingState> {
    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        [
            BatchStorageSubscriptionRequest(
                innerRequest: UnkeyedSubscriptionRequest(
                    storagePath: SystemPallet.blockNumberPath,
                    localKey: ""
                ),
                mappingKey: nil
            )
        ]
    }
}

extension ChainPollingStateStore: ChainPollingStateStoring {}
