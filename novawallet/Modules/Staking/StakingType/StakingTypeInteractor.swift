import UIKit

final class StakingTypeInteractor {
    weak var presenter: StakingTypeInteractorOutputProtocol?
}

extension StakingTypeInteractor: StakingTypeInteractorInputProtocol {}
