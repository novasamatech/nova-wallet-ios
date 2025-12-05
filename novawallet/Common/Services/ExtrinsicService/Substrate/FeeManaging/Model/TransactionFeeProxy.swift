import Foundation
import BigInt

typealias TransactionFeeId = String

class TransactionFeeProxy<T> {
    enum State {
        case loading
        case loaded(result: Result<T, Error>)
    }

    struct StateKey: Hashable {
        let reuseIdentifier: TransactionFeeId
        let chainAssetId: ChainAssetId?
    }

    private var feeStore: [StateKey: State] = [:]

    func update(result: Result<T, Error>, for stateKey: StateKey) {
        switch result {
        case .success:
            feeStore[stateKey] = .loaded(result: result)
        case .failure:
            feeStore[stateKey] = nil
        }
    }

    func getCachedState(for stateKey: StateKey) -> State? {
        feeStore[stateKey]
    }

    func setCachedState(_ state: State, for stateKey: StateKey) {
        feeStore[stateKey] = state
    }
}
