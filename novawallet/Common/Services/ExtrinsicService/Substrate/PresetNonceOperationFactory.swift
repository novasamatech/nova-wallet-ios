import Foundation
import Operation_iOS
import SubstrateSdk

final class PresetNonceOperationFactory {
    let nonce: UInt32

    init(nonce: UInt32) {
        self.nonce = nonce
    }
}

extension PresetNonceOperationFactory: TransactionNonceOperationFactoryProtocol {
    func createWrapper(
        for _: ChainModel,
        connection _: JSONRPCEngine,
        accountIdClosure _: @escaping () throws -> AccountId
    ) -> CompoundOperationWrapper<UInt32> {
        .createWithResult(nonce)
    }
}
