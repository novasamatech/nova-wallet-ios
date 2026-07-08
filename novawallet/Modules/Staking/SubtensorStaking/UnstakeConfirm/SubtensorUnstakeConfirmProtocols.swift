import Foundation
import BigInt

protocol SubtensorUnstakeConfirmInteractorInputProtocol: PendingExtrinsicInteracting {
    func setup()
    func estimateFee()
    func confirm()
}

protocol SubtensorUnstakeConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveAMMPrice(spotPrice: Double?, taoReserve: UInt64, alphaInReserve: UInt64)
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>)
    func didReceiveError(_ error: Error)
    /// Called once reserves arrive with the Nova service-fee amount in plank
    /// (0.3% of min TAO out). Zero for root (netuid 0) or when `novaFeeAccountId` is nil.
    func didReceiveCommission(_ amount: BigUInt)
}

protocol SubtensorUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    BaseErrorPresentable, AddressOptionsPresentable, FeeRetryable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        locale: Locale
    )
}
