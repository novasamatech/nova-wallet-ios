import Foundation

typealias TransactionFeeId = String

class TransactionFeeProxy<T> {
    enum State {
        case loading
        case loaded(result: Result<T, Error>)
    }

    private var feeStore: [TransactionFeeId: State] = [:]

    func update(result: Result<T, Error>, for identifier: TransactionFeeId) {
        switch result {
        case .success:
            feeStore[identifier] = .loaded(result: result)
        case .failure:
            feeStore[identifier] = nil
        }
    }

    func getCachedState(for identifier: TransactionFeeId) -> State? {
        feeStore[identifier]
    }

    func setCachedState(_ state: State, for identifier: TransactionFeeId) {
        feeStore[identifier] = state
    }
}
