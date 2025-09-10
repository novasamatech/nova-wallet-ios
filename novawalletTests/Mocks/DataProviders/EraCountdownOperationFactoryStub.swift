import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

struct EraCountdownOperationFactoryStub: EraCountdownOperationFactoryProtocol {
    let eraCountdown: EraCountdown

    func fetchCountdownOperationWrapper(
        for _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<EraCountdown> {
        CompoundOperationWrapper.createWithResult(eraCountdown)
    }
}

extension EraCountdown {
    static var testStub: EraCountdown {
        EraCountdown(
            activeEra: 2541,
            currentEra: 2541,
            eraLength: 6,
            sessionLength: 600,
            activeEraStartSessionIndex: 14538,
            currentSessionIndex: 14538,
            currentEpochIndex: 14538,
            currentSlot: 271_216_483,
            genesisSlot: 262_493_679,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )
    }
}
