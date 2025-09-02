import Foundation
import Operation_iOS

final class ConstantHistoryFiltersProvider {
    let filters: [TransactionHistoryLocalFilterProtocol]

    init(filters: [TransactionHistoryLocalFilterProtocol]) {
        self.filters = filters
    }
}

extension ConstantHistoryFiltersProvider: TransactionHistoryFilterProviderProtocol {
    func createFiltersWrapper() -> CompoundOperationWrapper<[TransactionHistoryLocalFilterProtocol]> {
        .createWithResult(filters)
    }
}
