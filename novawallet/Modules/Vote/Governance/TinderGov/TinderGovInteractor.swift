import Foundation
import Operation_iOS

class TinderGovInteractor {
    weak var presenter: TinderGovInteractorOutputProtocol?

    private let referendumsObservableSource: ReferendumObservableSourceProtocol

    init(referendumsObservableSource: ReferendumObservableSourceProtocol) {
        self.referendumsObservableSource = referendumsObservableSource
    }
}

// MARK: TinderGovInteractorInputProtocol

extension TinderGovInteractor: TinderGovInteractorInputProtocol {
    func setup() {
        referendumsObservableSource.observe(self)
    }
}

// MARK: ReferendumsSourceObserver

extension TinderGovInteractor: ReferendumsSourceObserver {
    func didReceive(_ changes: [DataProviderChange<ReferendumLocal>]) {
        presenter?.didReceive(changes)
    }
}
