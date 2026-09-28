import Foundation

protocol SubtensorSubnetDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(title: String, price: String?, change: String?, subtitle: String)
    func didReceive(history: SubtensorPriceHistoryResult?)
    func didReceive(risk: String?)
    func didReceiveFavorite(_ isFavorite: Bool)
}

protocol SubtensorSubnetDetailsPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(_ period: SubtensorPricePeriod)
    func toggleFavorite()
    func selectValidator()
    func continueStaking()
}

protocol SubnetDetailsInteractorInputProtocol: AnyObject {
    func loadHistory(for subnet: SubtensorSubnetRef, period: SubtensorPricePeriod)
    func loadRisk(for netuid: UInt16)
}

protocol SubnetDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(history: SubtensorPriceHistoryResult)
    func didReceive(risk: SubtensorRankedSubnet?)
    func didFailHistory(_ error: Error)
}

protocol SubtensorSubnetDetailsWireframeProtocol: AnyObject {
    func complete(from view: SubtensorSubnetDetailsViewProtocol?)
    func showValidators(
        from view: SubtensorSubnetDetailsViewProtocol?,
        target: SubtensorStakeTarget,
        delegate: SubtensorSubnetSelectDelegate
    )
}
