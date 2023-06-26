import UIKit

final class StartStakingInfoInteractor {
    weak var presenter: StartStakingInfoInteractorOutputProtocol?
}

extension StartStakingInfoInteractor: StartStakingInfoInteractorInputProtocol {}
