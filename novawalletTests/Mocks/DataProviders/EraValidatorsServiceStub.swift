import Foundation
@testable import novawallet
import RobinHood
import SubstrateSdk

final class EraValidatorServiceStub: EraValidatorServiceProtocol {
    let info: EraStakersInfo

    init(info: EraStakersInfo) {
        self.info = info
    }

    func setup() {}

    func throttle() {}

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        return BaseOperation.createWithResult(info)
    }
}

extension EraValidatorServiceStub {
    static func westendStub() -> EraValidatorServiceProtocol {
        let info = EraStakersInfo(activeEra: 3131, validators: WestendStub.eraValidators)
        return EraValidatorServiceStub(info: info)
    }
}
