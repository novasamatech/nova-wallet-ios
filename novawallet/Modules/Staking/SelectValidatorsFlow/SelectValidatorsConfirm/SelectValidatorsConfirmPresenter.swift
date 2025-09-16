import Foundation
import Foundation_iOS
import BigInt

final class SelectValidatorsConfirmPresenter {
    weak var view: SelectValidatorsConfirmViewProtocol?
    let wireframe: SelectValidatorsConfirmWireframeProtocol
    let interactor: SelectValidatorsConfirmInteractorInputProtocol

    private var freeBalance: Decimal?
    private var transferableBalance: Decimal?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var minimalBalance: Decimal?
    private var minNominatorBond: Decimal?
    private var counterForNominators: UInt32?
    private var maxNominatorsCount: UInt32?
    private var stakingDuration: StakingDuration?

    var state: SelectValidatorsConfirmationModel?
    let logger: LoggerProtocol?
    let confirmationViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let localizationManager: LocalizationManagerProtocol
    let chain: ChainModel

    init(
        interactor: SelectValidatorsConfirmInteractorInputProtocol,
        wireframe: SelectValidatorsConfirmWireframeProtocol,
        confirmationViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.confirmationViewModelFactory = confirmationViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.assetInfo = assetInfo
        self.localizationManager = localizationManager
        self.chain = chain
    }

    private func provideConfirmationState() {
        guard let state = state else {
            return
        }

        do {
            let viewModel = try confirmationViewModelFactory.createViewModel(from: state)
            view?.didReceive(confirmationViewModel: viewModel)
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func provideHints() {
        guard let state = state else {
            return
        }

        if state.hasExistingBond {
            let viewModel = confirmationViewModelFactory.createChangeValidatorsHints()
            view?.didReceive(hintsViewModel: viewModel)
        } else {
            guard let duration = stakingDuration else {
                return
            }

            let viewModel = confirmationViewModelFactory.createStartStakingHints(from: duration)
            view?.didReceive(hintsViewModel: viewModel)
        }
    }

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

    private func provideAmount() {
        if let state = state, state.amountToBond > 0 {
            let viewModel = balanceViewModelFactory.lockingAmountFromPrice(
                state.amountToBond,
                priceData: priceData
            )

            view?.didReceive(amountViewModel: viewModel)
        } else {
            view?.didReceive(amountViewModel: nil)
        }
    }

    private func handle(error: Error) {
        let locale = localizationManager.selectedLocale

        if let confirmError = error as? SelectValidatorsConfirmError {
            guard let view = view else {
                return
            }

            switch confirmError {
            case .notEnoughFunds:
                wireframe.presentAmountTooHigh(from: view, locale: locale)
            case .feeNotReceived:
                wireframe.presentFeeNotReceived(from: view, locale: locale)
            case let .missingController(address):
                wireframe.presentMissingController(from: view, address: address, locale: locale)
            case .extrinsicFailed:
                wireframe.presentExtrinsicFailed(from: view, locale: locale)
            }
        } else {
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: locale,
                completionClosure: nil
            )
        }
    }
}

extension SelectValidatorsConfirmPresenter: SelectValidatorsConfirmPresenterProtocol {
    func setup() {
        provideFee()

        interactor.setup()
        interactor.estimateFee()
    }

    func selectWalletAccount() {
        guard let state = state, let view = view else {
            return
        }

        let locale = localizationManager.selectedLocale

        wireframe.presentAccountOptions(
            from: view,
            address: state.wallet.address,
            chain: chain,
            locale: locale
        )
    }

    func selectPayoutAccount() {
        guard let state = state else {
            return
        }

        if case let .payout(account) = state.rewardDestination, let view = view {
            let locale = localizationManager.selectedLocale

            wireframe.presentAccountOptions(
                from: view,
                address: account.address,
                chain: chain,
                locale: locale
            )
        }
    }

    func proceed() {
        guard let state = state else {
            return
        }

        let locale = localizationManager.selectedLocale

        let validators: [DataValidating] = [
            dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in
                self?.interactor.estimateFee()
            },

            dataValidatingFactory.canSpendAmount(
                balance: freeBalance,
                spendingAmount: state.amountToBond,
                locale: locale
            ),

            dataValidatingFactory.canPayFee(
                balance: transferableBalance,
                fee: fee,
                asset: assetInfo,
                locale: locale
            ),

            dataValidatingFactory.canPayFeeSpendingAmount(
                balance: freeBalance,
                fee: fee,
                spendingAmount: state.amountToBond,
                asset: assetInfo,
                locale: locale
            ),

            dataValidatingFactory.maxNominatorsCountNotApplied(
                counterForNominators: counterForNominators,
                maxNominatorsCount: maxNominatorsCount,
                hasExistingNomination: state.hasExistingNomination,
                locale: locale
            ),

            dataValidatingFactory.canNominate(
                amount: state.amount,
                minimalBalance: minimalBalance,
                minNominatorBond: minNominatorBond,
                locale: locale
            )
        ]

        DataValidationRunner(validators: validators).runValidation { [weak self] in
            self?.interactor.submitNomination()
        }
    }
}

extension SelectValidatorsConfirmPresenter: SelectValidatorsConfirmInteractorOutputProtocol {
    func didReceiveModel(result: Result<SelectValidatorsConfirmationModel, Error>) {
        switch result {
        case let .success(model):
            state = model

            provideAmount()
            provideConfirmationState()
            provideHints()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceivePrice(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAmount()
            provideFee()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>) {
        switch result {
        case let .success(assetBalance):
            if let assetBalance = assetBalance {
                freeBalance = Decimal.fromSubstrateAmount(
                    assetBalance.freeInPlank,
                    precision: assetInfo.assetPrecision
                )

                transferableBalance = Decimal.fromSubstrateAmount(
                    assetBalance.transferable,
                    precision: assetInfo.assetPrecision
                )
            } else {
                freeBalance = 0.0
                transferableBalance = 0.0
            }
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMinBond(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minBond):
            minNominatorBond = minBond.map {
                Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision)
            } ?? nil
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(maxNominatorsCount):
            self.maxNominatorsCount = maxNominatorsCount
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveCounterForNominators(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(counterForNominators):
            self.counterForNominators = counterForNominators
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveStakingDuration(result: Result<StakingDuration, Error>) {
        switch result {
        case let .success(duration):
            stakingDuration = duration
            provideHints()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didStartNomination() {
        view?.didStartLoading()
    }

    func didCompleteNomination(submission: ExtrinsicSubmittedModel) {
        logger?.info("Did send nomination: \(submission)")

        view?.didStopLoading()

        wireframe.presentExtrinsicSubmission(
            from: view,
            sender: submission.sender,
            completionAction: .dismiss,
            locale: localizationManager.selectedLocale
        )
    }

    func didFailNomination(error: Error) {
        view?.didStopLoading()

        handle(error: error)
    }

    func didReceive(paymentInfo: ExtrinsicFeeProtocol) {
        fee = paymentInfo

        provideFee()
    }

    func didReceive(feeError: Error) {
        handle(error: feeError)
    }
}
