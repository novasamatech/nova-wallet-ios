import Foundation

typealias SubtensorUnstakeConfirmViewProtocol = SubtensorStakingConfirmViewProtocol

protocol SubtensorUnstakeConfirmInputProtocol: SubtensorConfirmInteractorInputProtocol {
    func loadRootHolds(for hotkeys: [AccountId])
    func loadCostBasis(for netuid: UInt16)
}

protocol SubtensorUnstakeConfirmOutputProtocol: SubtensorConfirmInteractorOutputProtocol {
    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold])
    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?)
}

protocol SubtensorUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, MessageSheetPresentable, SubtensorStakingErrorPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable, SubtensorOperationResultPresenting {}
