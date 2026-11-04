import Foundation
import Operation_iOS

protocol HydraAaveReservesDiscoveryFactoryProtocol {
    func createPairsWrapper() -> CompoundOperationWrapper<[HydraAave.TradePair]>
}
