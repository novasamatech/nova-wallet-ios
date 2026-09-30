import Foundation
import Operation_iOS

protocol SubtensorResultViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: SubtensorOperationResultViewModel)
    func didUpdateCountdown(remainedTime: UInt)
}

protocol SubtensorResultPresenterProtocol: AnyObject {
    func setup()
    func activate(action: SubtensorResultAction)
    func goBack()
    func showInfo(for row: SubtensorResultInfoRow)
}

protocol SubtensorResultInteractorInputProtocol: AnyObject {
    func setup()
    func fetchBlockTimestamp(at blockHash: BlockHash)
    func fetchRootHoldRemainingBlocks(for hotkeys: [AccountId])
    func refreshPositions()
}

protocol SubtensorResultInteractorOutputProtocol: AnyObject {
    func didReceiveSubmission(result: Result<SubtensorStakingOperationOutcome, SubtensorStakingSubmissionFailure>)
    func didReachConfirmationCap()
    func didReceiveExpectedBlockTime(_ blockTime: BlockTime)
    func didReceiveBlockTimestamp(_ date: Date, at blockHash: BlockHash)
    func didReceiveRootHoldRemainingBlocks(_ blocks: UInt64)
    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue)
    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos)
    func didBecomeActive()
}

protocol SubtensorResultWireframeProtocol: SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable,
    SubtensorYourBittensorPresentable {
    func closeForRetry(from view: ControllerBackedProtocol?, completion: @escaping () -> Void)
    func closeOperation(from view: ControllerBackedProtocol?)
    func showSubnetDiscovery(from view: ControllerBackedProtocol?)
    func presentSigningFailure(_ error: Error, from view: ControllerBackedProtocol?)
}

protocol SubtensorResultChainFactoryProtocol {
    func createExpectedBlockTimeWrapper() -> CompoundOperationWrapper<BlockTime>
    func createBlockTimestampWrapper(at blockHash: BlockHash) -> CompoundOperationWrapper<Date>
    func createRootHoldRemainingBlocksWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId]
    ) -> CompoundOperationWrapper<UInt64>
}
