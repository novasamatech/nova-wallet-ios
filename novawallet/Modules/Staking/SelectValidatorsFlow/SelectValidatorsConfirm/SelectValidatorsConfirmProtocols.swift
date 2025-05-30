import Foundation
import Foundation_iOS
import BigInt

protocol SelectValidatorsConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceive(confirmationViewModel: SelectValidatorsConfirmViewModel)
    func didReceive(hintsViewModel: LocalizableResource<[String]>)
    func didReceive(amountViewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol SelectValidatorsConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectWalletAccount()
    func selectPayoutAccount()
    func proceed()
}

protocol SelectValidatorsConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func submitNomination()
    func estimateFee()
}

protocol SelectValidatorsConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveModel(result: Result<SelectValidatorsConfirmationModel, Error>)
    func didReceivePrice(result: Result<PriceData?, Error>)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
    func didReceiveMinBond(result: Result<BigUInt?, Error>)
    func didReceiveCounterForNominators(result: Result<UInt32?, Error>)
    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>)
    func didReceiveStakingDuration(result: Result<StakingDuration, Error>)

    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)

    func didReceive(paymentInfo: ExtrinsicFeeProtocol)
    func didReceive(feeError: Error)
}

protocol SelectValidatorsConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, StakingErrorPresentable, MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(from view: SelectValidatorsConfirmViewProtocol?)
}
