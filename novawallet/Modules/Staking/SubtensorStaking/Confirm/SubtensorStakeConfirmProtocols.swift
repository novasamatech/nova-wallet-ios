import Foundation
import BigInt

protocol SubtensorStakeConfirmInteractorInputProtocol: PendingExtrinsicInteracting {
    func setup()
    func estimateFee()
    func confirm()
}

protocol SubtensorStakeConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveAMMPrice(spotPrice: Double?, taoReserve: UInt64, alphaInReserve: UInt64)
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>)
    func didReceiveError(_ error: Error)
    /// Called once (in `setup()`) with the Nova service-fee amount in plank.
    /// Zero for root (netuid 0) or when `novaFeeAccountId` is nil.
    func didReceiveCommission(_ amount: BigUInt)
}

protocol SubtensorStakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    BaseErrorPresentable, AddressOptionsPresentable, FeeRetryable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        locale: Locale
    )
}
