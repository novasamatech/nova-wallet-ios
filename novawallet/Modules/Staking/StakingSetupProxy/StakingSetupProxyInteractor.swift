import UIKit

final class StakingSetupProxyInteractor {
    weak var presenter: StakingSetupProxyInteractorOutputProtocol?
}

extension StakingSetupProxyInteractor: StakingSetupProxyInteractorInputProtocol {}
