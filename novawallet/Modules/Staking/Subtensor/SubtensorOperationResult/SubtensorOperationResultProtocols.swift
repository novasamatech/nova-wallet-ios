import Foundation
import Operation_iOS

protocol SubtensorOperationResultViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorOperationResultViewModel)
    func didUpdateCountdown(remainedTime: UInt)
}

protocol SubtensorOperationResultPresenterProtocol: AnyObject {
    func setup()
    func activate(action: SubtensorResultAction)
    func goBack()
    func showInfo(for row: SubtensorResultInfoRow)
}

protocol SubtensorOperationResultInteractorInputProtocol: AnyObject {
    func setup()
    func fetchBlockTimestamp(at blockHash: BlockHash)
    func fetchRootHoldRemainingBlocks(for hotkeys: [AccountId])
}

protocol SubtensorOperationResultInteractorOutputProtocol: AnyObject {
    func didReceiveSubmission(result: Result<SubtensorOperationOutcome, SubtensorSubmissionFailure>)
    func didSelectRoute(_ route: SubtensorSubmissionRoute)
    func didReachConfirmationCap()
    func didReceiveBlockTimestamp(_ date: Date, at blockHash: BlockHash)
    func didReceiveRootHoldRemainingBlocks(_ blocks: UInt64)
    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos)
}

protocol SubtensorOperationResultWireframeProtocol: SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable,
    SubtensorYourBittensorPresentable {
    func closeForRetry(from view: ControllerBackedProtocol?, completion: @escaping () -> Void)
    func closeOperation(from view: ControllerBackedProtocol?)
    func showSubnetDiscovery(from view: ControllerBackedProtocol?)
    func presentSigningFailure(_ error: Error, from view: ControllerBackedProtocol?)
}

protocol SubtensorOperationResultChainOperationFactoryProtocol {
    func createBlockTimestampWrapper(at blockHash: BlockHash) -> CompoundOperationWrapper<Date>
    func createRootHoldRemainingBlocksWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<UInt64>
}
