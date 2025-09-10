import Foundation
import Operation_iOS
@testable import novawallet

final class PayoutRewardsServiceStub: PayoutRewardsServiceProtocol {
    let result: Result<PayoutsInfo, Error>

    var fetchPayoutsCounter = 0

    init(result: Result<PayoutsInfo, Error>) {
        self.result = result
    }

    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<PayoutsInfo> {
        fetchPayoutsCounter += 1
        switch result {
        case let .success(payoutsInfo):
            return CompoundOperationWrapper.createWithResult(payoutsInfo)
        case let .failure(error):
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}

extension PayoutRewardsServiceStub {
    static func dummy() -> PayoutRewardsServiceStub {
        let payouts: [PayoutInfo] = [
            .init(validator: Data(), era: 99, pages: [0], reward: 0.1, identity: nil),
            .init(validator: Data(), era: 98, pages: [0], reward: 0.2, identity: nil),
            .init(validator: Data(), era: 97, pages: [0], reward: 0.3, identity: nil),
            .init(validator: Data(), era: 96, pages: [0], reward: 0.4, identity: nil)
        ]
        let payoutsInfo = PayoutsInfo(activeEra: 100, historyDepth: 84, payouts: payouts)
        return PayoutRewardsServiceStub(result: .success(payoutsInfo))
    }

    static func error() -> PayoutRewardsServiceStub {
        PayoutRewardsServiceStub(result: .failure(PayoutRewardsServiceError.unknown))
    }
}
