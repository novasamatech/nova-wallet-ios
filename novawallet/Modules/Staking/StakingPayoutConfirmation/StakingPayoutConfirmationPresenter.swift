import Foundation
import BigInt

final class StakingPayoutConfirmationPresenter {
    weak var view: StakingPayoutConfirmationViewProtocol?
    var wireframe: StakingPayoutConfirmationWireframeProtocol!
    var interactor: StakingPayoutConfirmationInteractorInputProtocol!

    private var balance: Decimal?
    private var fee: ExtrinsicFeeProtocol?
    private var rewardAmount: Decimal = 0.0
    private var priceData: PriceData?
    private var account: MetaChainAccountResponse?

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let payoutConfirmViewModelFactory: StakingPayoutConfirmViewModelFactoryProtocol
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let assetInfo: AssetBalanceDisplayInfo
    private let chain: ChainModel
    private let logger: LoggerProtocol?

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        payoutConfirmViewModelFactory: StakingPayoutConfirmViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel,
        logger: LoggerProtocol? = nil
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.payoutConfirmViewModelFactory = payoutConfirmViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
        self.chain = chain
        self.logger = logger
    }

    // MARK: - Private functions

    private func provideFee() {
        if let fee = fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(
                fee.amount.decimal(assetInfo: assetInfo),
                priceData: priceData
            )
            view?.didReceive(feeViewModel: viewModel)
        } else {
            view?.didReceive(feeViewModel: nil)
        }
    }

    private func provideViewModel() {
        guard
            let account = self.account,
            let viewModel = try? payoutConfirmViewModelFactory.createPayoutConfirmViewModel(with: account)
        else { return }

        view?.didRecieve(viewModel: viewModel)
    }

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(rewardAmount, priceData: priceData)
        view?.didRecieve(amountViewModel: viewModel)
    }

    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
            error,
            view: view,
            closeAction: .dismiss,
            locale: locale,
            completionClosure: nil
        )
    }
}

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationPresenterProtocol {
    func setup() {
        provideFee()
        provideAmountViewModel()
        interactor.setup()
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let feeDecimal = fee.map { $0.amount.decimal(assetInfo: assetInfo) }

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in
                self?.interactor.estimateFee()
            },

            dataValidatingFactory.rewardIsHigherThanFee(
                reward: rewardAmount,
                fee: feeDecimal,
                locale: locale
            ),

            dataValidatingFactory.canPayFee(
                balance: balance,
                fee: fee,
                asset: assetInfo,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.interactor.submitPayout()
        }
    }

    func presentAccountOptions() {
        guard let view = view, let address = account?.chainAccount.toAddress() else {
            return
        }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: locale
        )
    }
}

// MARK: - StakingPayoutConfirmationInteractorOutputProtocol

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationInteractorOutputProtocol {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(fee):
            self.fee = fee
            provideFee()

        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideFee()
            provideViewModel()
            provideAmountViewModel()

        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>) {
        switch result {
        case let .success(assetBalance):
            if let availableValue = assetBalance?.transferable {
                balance = Decimal.fromSubstrateAmount(
                    availableValue,
                    precision: assetInfo.assetPrecision
                )
            } else {
                balance = 0.0
            }

        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didStartPayout() {
        view?.didStartLoading()
    }

    func didCompletePayout(by sender: ExtrinsicSenderResolution) {
        logger?.info("Did send payouts by: \(sender)")

        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: view,
            sender: sender,
            completionAction: .dismiss,
            locale: view?.selectedLocale
        )
    }

    func didFailPayout(error: Error) {
        view?.didStopLoading()

        handle(error: error)
    }

    func didRecieve(account: MetaChainAccountResponse, rewardAmount: Decimal) {
        self.account = account
        self.rewardAmount = rewardAmount

        provideViewModel()
        provideAmountViewModel()
    }
}
