import UIKit

final class TinderGovInteractor {
    weak var presenter: TinderGovInteractorOutputProtocol?
}

extension TinderGovInteractor: TinderGovInteractorInputProtocol {}