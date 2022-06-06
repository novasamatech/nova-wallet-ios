import UIKit

final class ParaStkRebondInteractor {
    weak var presenter: ParaStkRebondInteractorOutputProtocol!
}

extension ParaStkRebondInteractor: ParaStkRebondInteractorInputProtocol {}
