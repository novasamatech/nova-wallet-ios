import Foundation
import Foundation_iOS
import BigInt

protocol MoonbeamTermsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol, Localizable {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>)
}

protocol MoonbeamTermsPresenterProtocol: AnyObject {
    func setup()
    func handleAction()
    func handleLearnTerms()
}

protocol MoonbeamTermsInteractorInputProtocol: AnyObject {
    var termsURL: URL { get }
    func setup()
    func submitAgreement()
    func estimateFee()
}

protocol MoonbeamTermsInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveVerifyRemark(result: Result<Bool, Error>)
    func didReceiveBalance(result: Result<AssetBalance?, Error>)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
}

protocol MoonbeamTermsWireframeProtocol: WebPresentable,
    StakingErrorPresentable,
    AlertPresentable,
    ErrorPresentable,
    CrowdloanErrorPresentable {
    func showContributionSetup(
        paraId: ParaId,
        moonbeamService: MoonbeamBonusServiceProtocol,
        state: CrowdloanSharedState,
        from view: ControllerBackedProtocol?
    )
}
