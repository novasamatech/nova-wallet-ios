import UIKit

final class MythosStkYourCollatorsInteractor {
    weak var presenter: MythosStkYourCollatorsInteractorOutputProtocol?
}

extension MythosStkYourCollatorsInteractor: MythosStkYourCollatorsInteractorInputProtocol {
    func setup() {}

    func retry() {}
}
