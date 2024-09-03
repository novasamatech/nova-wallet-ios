import Foundation

class TinderGovInteractor {
    weak var presenter: TinderGovInteractorOutputProtocol?

    // TODO: change to observable state
    private let referendums: [ReferendumLocal]

    init(referendums: [ReferendumLocal]) {
        self.referendums = referendums
    }
}

// MARK: TinderGovInteractorInputProtocol

extension TinderGovInteractor: TinderGovInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(referendums)
    }
}
