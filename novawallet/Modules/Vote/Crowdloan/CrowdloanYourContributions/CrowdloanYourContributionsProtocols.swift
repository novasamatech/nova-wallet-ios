import Foundation_iOS
import Foundation
import Operation_iOS

protocol CrowdloanContributionsViewProtocol: ControllerBackedProtocol {
    func reload(model: CrowdloanYourContributionsViewModel)
    func reload(returnInIntervals: [FormattedReturnInIntervalsViewModel])
    func reload(hasUnlockable: Bool)
}

protocol CrowdloanContributionsPresenterProtocol: AnyObject {
    func setup()
    func unlock()
}

protocol CrowdloanContributionsVMFactoryProtocol: AnyObject {
    func createViewModel(
        input: CrowdloanYourContributionsViewInput,
        price: PriceData?,
        locale: Locale
    ) -> CrowdloanYourContributionsViewModel

    func createReturnInIntervals(
        input: CrowdloanYourContributionsViewInput,
        metadata: CrowdloanMetadata
    ) -> [ReturnInIntervalsViewModel]
}

protocol CrowdloanContributionsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CrowdloanContributionsInteractorOutputProtocol: AnyObject {
    func didReceiveContributions(_ changes: [DataProviderChange<CrowdloanContribution>])
    func didReceiveBlockNumber(_ blockNumber: BlockNumber?)
    func didReceiveBlockDuration(_ blockDuration: BlockTime)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveError(_ error: Error)
}

protocol CrowdloanContributionsWireframeProtocol: AnyObject {}
