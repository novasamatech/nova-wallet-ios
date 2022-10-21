protocol ReferendumFullDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(proposerModel: ProposerTableCell.Model?)
    func didReceive(json: String?, jsonTitle: String)
    func didReceive(amountSpendDetails: AmountSpendDetailsTableView.Model?)
    func didReceive(deposit: MultiValueView.Model, title: String)
    func didReceive(
        approveCurve: TitleWithSubtitleViewModel?,
        supportCurve: TitleWithSubtitleViewModel?,
        callHash: TitleWithSubtitleViewModel?
    )
}

protocol ReferendumFullDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol ReferendumFullDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(json: String?)
    func didReceive(error: ReferendumFullDetailsError)
}

protocol ReferendumFullDetailsWireframeProtocol: AnyObject {}

protocol ReferendumFullDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

enum ReferendumFullDetailsError: Error {
    case priceFailed(Error)
    case emptyJSON
    case processingJSON(Error)
}
