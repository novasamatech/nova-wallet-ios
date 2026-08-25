import Foundation

enum SubtensorStakingFlowConstants {
    static let blockTimeMillis: BlockTime = 12000
}

// the estimator cannot see the fee-in-alpha path and alpha-paid fees are final,
// so every TAO-denominated fee estimate is displayed as approximate
extension BalanceViewModelProtocol {
    func approximatelyForSubtensorFee() -> BalanceViewModelProtocol {
        BalanceViewModel(amount: amount.approximately(), price: price)
    }
}

protocol SubtensorStakingBaseInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for call: SubtensorStakingCallModel)
    func refreshPreflight(for hotkey: AccountId)
}

protocol SubtensorStakingBaseInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?)
    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceivePreflight(_ preflight: SubtensorStakingPreflight)
    func didReceiveExistentialDeposit(_ deposit: Balance)
    func didReceiveBaseError(_ error: SubtensorStakingBaseError)
}

enum SubtensorStakingBaseError: Error {
    case feeFailed(Error)
    case preflightFailed(Error)
}

protocol SubtensorStakingDelegateInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func applyDelegate(with accountId: AccountId)
}

protocol SubtensorStakingDelegateInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveDelegateIdentities(_ identities: [AccountId: AccountIdentity]?)
}

protocol SubtensorStakingSubmitInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func submit(call: SubtensorStakingCallModel)
}

protocol SubtensorStakingSubmitInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<SubtensorSubmissionModel, Error>)
}
