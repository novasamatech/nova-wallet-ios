import UIKit

final class MythosStakingSetupInteractor {
    weak var presenter: MythosStakingSetupInteractorOutputProtocol?
}

extension MythosStakingSetupInteractor: MythosStakingSetupInteractorInputProtocol {}
