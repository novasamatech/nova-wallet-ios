import UIKit

final class ParaStkCollatorsSearchInteractor {
    weak var presenter: ParaStkCollatorsSearchInteractorOutputProtocol?
}

extension ParaStkCollatorsSearchInteractor: ParaStkCollatorsSearchInteractorInputProtocol {}
