import UIKit

final class StakingSetupProxyInteractor: StakingProxyBaseInteractor {
    weak var presenter: StakingSetupProxyInteractorOutputProtocol? {
        basePresenter as? StakingSetupProxyInteractorOutputProtocol
    }
}

extension StakingSetupProxyInteractor: StakingSetupProxyInteractorInputProtocol {}
