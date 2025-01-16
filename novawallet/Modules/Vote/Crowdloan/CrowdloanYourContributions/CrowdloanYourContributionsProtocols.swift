import Foundation_iOS
import Foundation

protocol CrowdloanYourContributionsViewProtocol: ControllerBackedProtocol {
    func reload(model: CrowdloanYourContributionsViewModel)
    func reload(returnInIntervals: [FormattedReturnInIntervalsViewModel])
}

protocol CrowdloanYourContributionsPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanYourContributionsVMFactoryProtocol: AnyObject {
    func createViewModel(
        input: CrowdloanYourContributionsViewInput,
        externalContributions: [ExternalContribution]?,
        amount: Decimal,
        price: PriceData?,
        locale: Locale
    ) -> CrowdloanYourContributionsViewModel

    func createReturnInIntervals(
        input: CrowdloanYourContributionsViewInput,
        externalContributions: [ExternalContribution]?,
        metadata: CrowdloanMetadata
    ) -> [ReturnInIntervalsViewModel]
}

protocol CrowdloanYourContributionsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CrowdloanYourContributionsInteractorOutputProtocol: AnyObject {
    func didReceiveExternalContributions(_ externalContributions: [ExternalContribution])
    func didReceiveBlockNumber(_ blockNumber: BlockNumber?)
    func didReceiveBlockDuration(_ blockDuration: BlockTime)
    func didReceiveLeasingPeriod(_ leasingPeriod: LeasingPeriod)
    func didReceiveLeasingOffset(_ leasingOffset: LeasingOffset)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveError(_ error: Error)
}

protocol CrowdloanYourContributionsWireframeProtocol: AnyObject {}
