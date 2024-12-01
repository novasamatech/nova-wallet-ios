import Foundation

final class AssetHubReQuoteService: ObservableSubscriptionSyncService<ObservableSubscriptionState> {
    override func getRequests() throws -> [BatchStorageSubscriptionRequest] {
        let blockNumberRequest = BatchStorageSubscriptionRequest(
            innerRequest: UnkeyedSubscriptionRequest(
                storagePath: SystemPallet.blockNumberPath,
                localKey: ""
            ),
            mappingKey: nil
        )

        return [blockNumberRequest]
    }
}
