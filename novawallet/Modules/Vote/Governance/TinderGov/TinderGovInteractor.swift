import Foundation
import Operation_iOS

class TinderGovInteractor {
    weak var presenter: TinderGovInteractorOutputProtocol?

    private let observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>>

    init(observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>>) {
        self.observableState = observableState
    }
}

// MARK: TinderGovInteractorInputProtocol

extension TinderGovInteractor: TinderGovInteractorInputProtocol {
    func setup() {
        let changes: [DataProviderChange<ReferendumLocal>] = observableState
            .state
            .value
            .map { .insert(newItem: $1) }

        presenter?.didReceive(changes)

        startObservingState()
    }
}

// MARK: Private

extension TinderGovInteractor {
    func startObservingState() {
        observableState.addObserver(
            with: self,
            queue: .main
        ) { [weak self] old, new in
            let insertsAndUpdates: [DataProviderChange<ReferendumLocal>] = new.value.compactMap {
                old.value[$0.key] == nil
                    ? .insert(newItem: $0.value)
                    : .update(newItem: $0.value)
            }

            let deletes: [DataProviderChange<ReferendumLocal>] = old.value.compactMap {
                new.value[$0.key] == nil
                    ? .delete(deletedIdentifier: "\($0.value.index)")
                    : nil
            }

            self?.presenter?.didReceive(insertsAndUpdates + deletes)
        }
    }
}
