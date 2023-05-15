import Foundation
import SoraFoundation
import RobinHood

final class ReferendumSearchPresenter {
    weak var view: ReferendumSearchViewProtocol?
    let wireframe: ReferendumSearchWireframeProtocol
    let logger: LoggerProtocol?
    let referendumsState: Observable<ReferendumsState>
    private weak var delegate: ReferendumSearchDelegate?
    private var currentSearchOperation: CancellableCall?
    private var searchModel = ReferendumsSearchModel(cells: [])
    private let operationQueue: OperationQueue
    private let localizationManager: LocalizationManagerProtocol

    init(
        wireframe: ReferendumSearchWireframeProtocol,
        delegate: ReferendumSearchDelegate?,
        referendumsState: Observable<ReferendumsState>,
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
    }
}

extension ReferendumSearchPresenter: ReferendumSearchPresenterProtocol {
    func search(for text: String) {
        currentSearchOperation?.cancel()

        let searchOperation = searchModel.searchOperation(text: text)
        searchOperation.completionBlock = { [weak self] in
            do {
                let referendums = try searchOperation.extractNoCancellableResultData()
                DispatchQueue.main.async {
                    self?.view?.didReceive(viewModel: .found(
                        title: .init(title: ""),
                        items: referendums
                    ))
                }
            } catch {
                self?.didReceiveError(.searchFailed(text, error))
            }
        }

        currentSearchOperation = searchOperation

        operationQueue.addOperation(searchOperation)
    }

    func setup() {
        view?.didReceive(viewModel: .start)

        searchModel = ReferendumsSearchModel(cells: referendumsState.state.cells)
        view?.updateReferendums(time: referendumsState.state.timeModels ?? [:])
        view?.didReceive(viewModel: .found(
            title: .init(title: ""),
            items: referendumsState.state.cells
        ))
        referendumsState.addObserver(with: self) { [weak self] old, new in
            if old.cells != new.cells {
                self?.searchModel = ReferendumsSearchModel(cells: new.cells)
                self?.view?.didReceive(viewModel: .found(
                    title: .init(title: ""),
                    items: new.cells
                ))
            }

            if old.timeModels != new.timeModels {
                self?.view?.updateReferendums(time: new.timeModels ?? [:])
            }
        }
    }

    func cancel() {
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
        case let .searchFailed(text, error):
            wireframe.presentRequestStatus(
                on: view,
                locale: localizationManager.selectedLocale
            ) { [weak self] in
                self?.search(for: text)
            }
        }
    }
}
