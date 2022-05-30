protocol ParaStkCollatorInfoViewProtocol: AnyObject {}

protocol ParaStkCollatorInfoPresenterProtocol: AnyObject {
    func setup()
}

protocol ParaStkCollatorInfoInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ParaStkCollatorInfoInteractorOutputProtocol: AnyObject {
    func didReceivePrice(result: Result<PriceData?, Error>)
}

protocol ParaStkCollatorInfoWireframeProtocol: AnyObject {}
