import BigInt

protocol NominationPoolBondMoreViewProtocol: ControllerBackedProtocol {}

protocol NominationPoolBondMorePresenterProtocol: AnyObject {
    func setup()
}

protocol NominationPoolBondMoreInteractorInputProtocol: NominationPoolBondMoreBaseInteractorInputProtocol {}

protocol NominationPoolBondMoreInteractorOutputProtocol: NominationPoolBondMoreBaseInteractorOutputProtocol {}

protocol NominationPoolBondMoreWireframeProtocol: NominationPoolBondMoreBaseWireframeProtocol {}
