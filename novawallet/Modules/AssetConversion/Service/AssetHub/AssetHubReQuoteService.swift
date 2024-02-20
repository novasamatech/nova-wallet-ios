import Foundation

final class AssetHubReQuoteService: ObservableSubscriptionSyncService<ObservableSubscriptionState> {
    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        let blockNumberRequest = BatchStorageSubscriptionRequest(
            innerRequest: UnkeyedSubscriptionRequest(
                storagePath: .blockNumber,
                localKey: ""
            ),
            mappingKey: nil
        )

        return [blockNumberRequest]
    }
}
