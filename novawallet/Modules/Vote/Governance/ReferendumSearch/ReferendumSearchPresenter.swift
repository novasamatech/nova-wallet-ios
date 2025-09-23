import Foundation
import Foundation_iOS
import Operation_iOS

final class ReferendumSearchPresenter {
    weak var view: ReferendumSearchViewProtocol?
    let wireframe: ReferendumSearchWireframeProtocol
    let logger: LoggerProtocol?
    let referendumsState: Observable<ReferendumsViewState>
    let localizationManager: LocalizationManagerProtocol
    let searchOperationFactory: ReferendumsSearchOperationFactoryProtocol

    private weak var delegate: ReferendumSearchDelegate?
    private var currentSearchOperation: CancellableCall?
    private var searchOperationClosure: ReferendumsSearchOperationClosure

    private let operationQueue: OperationQueue

    init(
        wireframe: ReferendumSearchWireframeProtocol,
        delegate: ReferendumSearchDelegate?,
        referendumsState: Observable<ReferendumsViewState>,
        searchOperationFactory: ReferendumsSearchOperationFactoryProtocol,
        operationQueue: OperationQueue,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.delegate = delegate
        self.operationQueue = operationQueue
        self.logger = logger
        self.localizationManager = localizationManager
        self.wireframe = wireframe
        self.referendumsState = referendumsState
        self.searchOperationFactory = searchOperationFactory
        searchOperationClosure = searchOperationFactory.createOperationClosure(cells: [])
    }

    deinit {
        referendumsState.removeObserver(by: self)
    }

    private func updateReferendumsViewModels(_ models: [ReferendumsCellViewModel]) {
        searchOperationClosure = searchOperationFactory.createOperationClosure(cells: models)
        view?.didReceive(viewModel: .found(
            title: .init(title: ""),
            items: models
        ))
    }

    private func updateTimeModels(_ timeModels: [UInt: StatusTimeViewModel?]?) {
        view?.updateReferendums(time: timeModels ?? [:])
    }

    private func setupInitialState() {
        updateReferendumsViewModels(referendumsState.state.cells.map(\.originalContent))
        updateTimeModels(referendumsState.state.timeModels)
    }
}

extension ReferendumSearchPresenter: ReferendumSearchPresenterProtocol {
    func setup() {
        view?.didReceive(viewModel: .start)
        setupInitialState()

        referendumsState.addObserver(with: self) { [weak self] old, new in
            if old.cells != new.cells {
                self?.updateReferendumsViewModels(new.cells.map(\.originalContent))
            }

            if old.timeModels != new.timeModels {
                self?.updateTimeModels(new.timeModels)
            }
        }
    }

    func search(for text: String) {
        currentSearchOperation?.cancel()

        let searchOperation = searchOperationClosure(text)
        searchOperation.completionBlock = { [weak self] in
            do {
                let referendums = try searchOperation.extractNoCancellableResultData()
                DispatchQueue.main.async {
                    if referendums.isEmpty {
                        self?.view?.didReceive(viewModel: .notFound)
                    } else {
                        self?.view?.didReceive(viewModel: .found(
                            title: .init(title: ""),
                            items: referendums
                        ))
                    }
                }
            } catch {
                self?.didReceiveError(.searchFailed(text, error))
            }
        }

        currentSearchOperation = searchOperation
        operationQueue.addOperation(searchOperation)
    }

    func cancel() {
        currentSearchOperation?.cancel()
        wireframe.finish(from: view)
    }

    func select(referendumIndex: UInt) {
        delegate?.didSelectReferendum(referendumIndex: referendumIndex)
        wireframe.finish(from: view)
    }
}

extension ReferendumSearchPresenter {
    func didReceiveError(_ error: ReferendumSearchError) {
        switch error {
        case let .searchFailed(text, _):
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.search(for: text)
            }
        }
    }
}
