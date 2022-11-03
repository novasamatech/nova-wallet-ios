protocol ReferendumFullDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(proposer: ReferendumFullDetailsViewModel.Proposer?)
    func didReceive(beneficiary: ReferendumFullDetailsViewModel.Beneficiary?)
    func didReceive(params: ReferendumFullDetailsViewModel.CurveAndHash?)
    func didReceive(json: String?)
    func didReceiveTooLongJson()
}

protocol ReferendumFullDetailsPresenterProtocol: AnyObject {
    func setup()
    func presentProposer()
    func presentBeneficiary()
    func presentCallHash()
}

protocol ReferendumFullDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func refreshCall()
}

protocol ReferendumFullDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(call: ReferendumActionLocal.Call<String>?)
    func didReceive(error: ReferendumFullDetailsError)
}

protocol ReferendumFullDetailsWireframeProtocol: ErrorPresentable, AlertPresentable, AddressOptionsPresentable,
    CommonRetryable, CopyPresentable {}

enum ReferendumFullDetailsError: Error {
    case priceFailed(Error)
    case processingJSON(Error)
}
