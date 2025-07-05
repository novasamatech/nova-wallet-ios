protocol MultisigTxDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MultisigTxDetailsViewModel)
    func didReceive(
        depositViewModel: MultisigTxDetailsViewModel.SectionField<BalanceViewModelProtocol>
    )
}

protocol MultisigTxDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigTxDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigTxDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(priceData: PriceData?)
    func didReceive(prettifiedCallString: String)
    func didReceive(txDetails: MultisigTxDetails)
    func didReceive(error: Error)
}

protocol MultisigTxDetailsWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    AddressOptionsPresentable {}
