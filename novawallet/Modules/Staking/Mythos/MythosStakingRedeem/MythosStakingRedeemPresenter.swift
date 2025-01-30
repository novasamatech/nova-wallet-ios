import Foundation

final class MythosStakingRedeemPresenter {
    weak var view: CollatorStakingRedeemViewProtocol?
    let wireframe: MythosStakingRedeemWireframeProtocol
    let interactor: MythosStakingRedeemInteractorInputProtocol

    init(
        interactor: MythosStakingRedeemInteractorInputProtocol,
        wireframe: MythosStakingRedeemWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MythosStakingRedeemPresenter: CollatorStakingRedeemPresenterProtocol {
    func setup() {
        
    }
    
    func selectAccount() {
        
    }
    
    func confirm() {
        
    }
}

extension MythosStakingRedeemPresenter: MythosStakingRedeemInteractorOutputProtocol {}
