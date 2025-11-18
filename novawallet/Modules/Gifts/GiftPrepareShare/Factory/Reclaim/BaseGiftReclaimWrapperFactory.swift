import Foundation
import Operation_iOS

protocol GiftReclaimStatusUpdating {
    var giftRepository: AnyDataProviderRepository<GiftModel> { get }

    func createPersistedStatusUpdateOperation(
        for gift: GiftModel,
        dependingOn reclaimWrapper: CompoundOperationWrapper<Void>
    ) -> BaseOperation<Void>
}

extension GiftReclaimStatusUpdating {
    func createPersistedStatusUpdateOperation(
        for gift: GiftModel,
        dependingOn reclaimWrapper: CompoundOperationWrapper<Void>
    ) -> BaseOperation<Void> {
        giftRepository.saveOperation(
            {
                _ = try reclaimWrapper.targetOperation.extractNoCancellableResultData()

                return [gift.updating(status: .reclaimed)]
            },
            { [] }
        )
    }
}
