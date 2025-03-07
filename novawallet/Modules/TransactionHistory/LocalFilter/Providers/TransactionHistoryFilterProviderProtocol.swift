import Foundation
import Operation_iOS

protocol TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]>
}
