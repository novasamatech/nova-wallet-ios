import Foundation
@testable import novawallet
import Operation_iOS

final class UnstakingDurationOperationFactoryMock {
    let unstakingDuration: UnstakingDuration
    let durationVariant: UnstakingDurationVariant

    init(
        unstakingDuration: UnstakingDuration = UnstakingDuration(validator: 28, nominator: 28),
        durationVariant: UnstakingDurationVariant = .full
    ) {
        self.unstakingDuration = unstakingDuration
        self.durationVariant = durationVariant
    }
}

extension UnstakingDurationOperationFactoryMock: UnstakingDurationOperationMaking {
    func createUnstakingDurationWrapper(
        for _: ChainModel.Id
    ) -> CompoundOperationWrapper<UnstakingDuration> {
        CompoundOperationWrapper.createWithResult(unstakingDuration)
    }

    func createStashDurationVariantWrapper(
        for _: @escaping () throws -> AccountId,
        chainId _: ChainModel.Id
    ) -> CompoundOperationWrapper<UnstakingDurationVariant> {
        CompoundOperationWrapper.createWithResult(durationVariant)
    }
}
