import UIKit

final class GiftListInteractor {
    weak var presenter: GiftListInteractorOutputProtocol?
}

extension GiftListInteractor: GiftListInteractorInputProtocol {}