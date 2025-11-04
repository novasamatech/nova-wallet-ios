import UIKit

final class GiftClaimInteractor {
    weak var presenter: GiftClaimInteractorOutputProtocol?
}

extension GiftClaimInteractor: GiftClaimInteractorInputProtocol {}