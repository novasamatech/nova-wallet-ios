import Foundation_iOS
import Foundation

protocol CrowdloanContributionsViewProtocol: ControllerBackedProtocol {
    func reload(model: CrowdloanYourContributionsViewModel)
    func reload(returnInIntervals: [FormattedReturnInIntervalsViewModel])
}

protocol CrowdloanContributionsPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanContributionsVMFactoryProtocol: AnyObject {
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

protocol CrowdloanContributionsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CrowdloanContributionsInteractorOutputProtocol: AnyObject {
    func didReceiveContributions(_ contributions: [CrowdloanContribution])
    func didReceiveBlockNumber(_ blockNumber: BlockNumber?)
    func didReceiveBlockDuration(_ blockDuration: BlockTime)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveError(_ error: Error)
}

protocol CrowdloanContributionsWireframeProtocol: AnyObject {}
