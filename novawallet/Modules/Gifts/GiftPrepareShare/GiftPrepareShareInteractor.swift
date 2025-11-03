import UIKit

final class GiftPrepareShareInteractor {
    weak var presenter: GiftPrepareShareInteractorOutputProtocol?
}

extension GiftPrepareShareInteractor: GiftPrepareShareInteractorInputProtocol {}
