import Foundation

typealias SubtensorUnstakeConfirmViewProtocol = SubtensorStakingConfirmViewProtocol

protocol SubtensorUnstakeConfirmInputProtocol: SubtensorConfirmInteractorInputProtocol {
    func loadRootHolds(for hotkeys: [AccountId])
}

protocol SubtensorUnstakeConfirmOutputProtocol: SubtensorConfirmInteractorOutputProtocol {
    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold])
}

protocol SubtensorUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, MessageSheetPresentable, SubtensorStakingErrorPresentable, SubtensorInfoSheetPresentable,
    SubtensorValidatorInfoPresentable, SubtensorOperationResultPresenting {}
