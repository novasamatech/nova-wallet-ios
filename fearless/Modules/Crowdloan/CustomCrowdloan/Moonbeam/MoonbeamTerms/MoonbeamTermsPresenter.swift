import Foundation
import BigInt
import SoraFoundation

final class MoonbeamTermsPresenter {
    weak var view: MoonbeamTermsViewProtocol?
    let assetInfo: AssetBalanceDisplayInfo
    let wireframe: MoonbeamTermsWireframeProtocol
    let interactor: MoonbeamTermsInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let paraId: ParaId
    let moonbeamService: MoonbeamBonusServiceProtocol
    let state: CrowdloanSharedState
    let logger: LoggerProtocol?

    private var priceData: PriceData?
    private var fee: Decimal?

    init(
        paraId: ParaId,
        moonbeamService: MoonbeamBonusServiceProtocol,
        state: CrowdloanSharedState,
        assetInfo: AssetBalanceDisplayInfo,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        interactor: MoonbeamTermsInteractorInputProtocol,
        wireframe: MoonbeamTermsWireframeProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.paraId = paraId
        self.moonbeamService = moonbeamService
        self.state = state
        self.assetInfo = assetInfo
        self.balanceViewModelFactory = balanceViewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }

    private func updateView() {
        provideFeeViewModel()
    }

    private func provideFeeViewModel() {
        guard let fee = fee else { return }
        let feeViewModel = balanceViewModelFactory
            .balanceFromPrice(fee, priceData: priceData)
        view?.didReceiveFee(viewModel: feeViewModel)
    }
}

extension MoonbeamTermsPresenter: MoonbeamTermsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleAction() {
        view?.didStartLoading()
        interactor.submitAgreement()
    }

    func handleLearnTerms() {
        guard let view = view else { return }
        wireframe.showWeb(url: interactor.termsURL, from: view, style: .automatic)
    }
}

extension MoonbeamTermsPresenter: MoonbeamTermsInteractorOutputProtocol {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision)
            } ?? nil

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive price error: \(error)")
        }
    }

    func didReceiveVerifyRemark(result: Result<Bool, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(verified):
            if verified {
                wireframe.showContributionSetup(
                    paraId: paraId,
                    moonbeamService: moonbeamService,
                    state: state,
                    from: view
                )
            }
        case let .failure(error):
            logger?.error("Did receive verify remark error: \(error)")
        }
    }
}
