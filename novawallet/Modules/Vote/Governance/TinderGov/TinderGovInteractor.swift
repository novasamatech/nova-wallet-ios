import Foundation
import Operation_iOS

class TinderGovInteractor {
    weak var presenter: TinderGovInteractorOutputProtocol?

    private let observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>>
    private let sorting: ReferendumsSorting
    private let operationQueue: OperationQueue

    private var modelBuilder: TinderGovModelBuilder?

    init(
        observableState: Observable<NotEqualWrapper<[ReferendumIdLocal: ReferendumLocal]>>,
        sorting: ReferendumsSorting,
        operationQueue: OperationQueue
    ) {
        self.observableState = observableState
        self.sorting = sorting
        self.operationQueue = operationQueue
    }
}

// MARK: TinderGovInteractorInputProtocol

extension TinderGovInteractor: TinderGovInteractorInputProtocol {
    func setup() {
        modelBuilder = .init(
            sorting: sorting,
            workingQueue: operationQueue
        ) { [weak self] result in
            self?.presenter?.didReceive(result)
        }

        modelBuilder?.buildOnSetup()
        modelBuilder?.apply(observableState.state.value)
        startObservingState()
    }

    func addVoting(for referendumId: ReferendumIdLocal) {
        modelBuilder?.apply(voting: referendumId)
    }
}

// MARK: Private

extension TinderGovInteractor {
    func startObservingState() {
        observableState.addObserver(
            with: self,
            queue: .main
        ) { [weak self] _, new in
            self?.modelBuilder?.apply(new.value)
        }
    }
}
