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
    let dataValidatingFactory: BaseDataValidatingFactoryProtocol

    private var priceData: PriceData?
    private var fee: Decimal?
    private var balance: Decimal?
    private var totalBalanceValue: BigUInt?
    private var minimumBalance: BigUInt?

    init(
        paraId: ParaId,
        moonbeamService: MoonbeamBonusServiceProtocol,
        state: CrowdloanSharedState,
        assetInfo: AssetBalanceDisplayInfo,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        interactor: MoonbeamTermsInteractorInputProtocol,
        wireframe: MoonbeamTermsWireframeProtocol,
        dataValidatingFactory: BaseDataValidatingFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.paraId = paraId
        self.moonbeamService = moonbeamService
        self.state = state
        self.assetInfo = assetInfo
        self.balanceViewModelFactory = balanceViewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    private func updateView() {
        provideFeeViewModel()
    }

    private func refreshFeeIfNeeded() {
        guard fee == nil else { return }
        interactor.estimateFee()
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
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        let spendingAmount = (fee?.toSubstrateAmount(precision: assetInfo.assetPrecision) ?? 0)

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),
            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                locale: locale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: spendingAmount,
                totalAmount: totalBalanceValue,
                minimumBalance: minimumBalance,
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.view?.didStartLoading()
            self?.interactor.submitAgreement()
        }
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
            if !wireframe.present(error: error, from: view, locale: view?.selectedLocale) {
                logger?.error("Did receive verify remark error: \(error)")
            }
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: assetInfo.assetPrecision
                )
                totalBalanceValue = accountInfo.data.total
            } else {
                balance = nil
            }
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            self.minimumBalance = minimumBalance
        case let .failure(error):
            logger?.error("Did receive minimum balance error: \(error)")
        }
    }
}
