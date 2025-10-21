import Foundation
import BigInt
import Foundation_iOS

final class StakingUnbondConfirmPresenter {
    weak var view: StakingUnbondConfirmViewProtocol?
    let wireframe: StakingUnbondConfirmWireframeProtocol
    let interactor: StakingUnbondConfirmInteractorInputProtocol

    let inputAmount: Decimal
    let confirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let chain: ChainModel
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol?

    private var bonded: Decimal?
    private var balance: Decimal?
    private var minimalBalance: Decimal?
    private var minNominatorBonded: Decimal?
    private var nomination: Staking.Nomination?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var controller: MetaChainAccountResponse?
    private var stashItem: StashItem?
    private var payee: Staking.RewardDestinationArg?
    private var stakingDuration: StakingDuration?

    private var shouldResetRewardDestination: Bool {
        switch payee {
        case .staked:
            if let bonded = bonded, let minimalBalance = minimalBalance {
                return bonded - inputAmount < minimalBalance
            } else {
                return false
            }
        default:
            return false
        }
    }

    private var shouldChill: Bool {
        if let bonded = bonded, let minNominatorBonded = minNominatorBonded, nomination != nil {
            return bonded - inputAmount < minNominatorBonded
        } else {
            return false
        }
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(
                fee.amount.decimal(assetInfo: assetInfo),
                priceData: priceData
            )
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.lockingAmountFromPrice(inputAmount, priceData: priceData)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideShouldResetRewardsDestination() {
        view?.didSetShouldResetRewardsDestination(value: shouldResetRewardDestination)
    }

    private func provideConfirmationViewModel() {
        guard let controller = controller else {
            return
        }

        do {
            let viewModel = try confirmViewModelFactory.createUnbondConfirmViewModel(
                controllerItem: controller
            )

            view?.didReceiveConfirmation(viewModel: viewModel)
        } catch {
            logger?.error("Did receive view model factory error: \(error)")
        }
    }

    private func provideBondingDuration() {
        guard let stakingDuration = stakingDuration else {
            return
        }

        view?.didReceiveBonding(duration: stakingDuration.localizableUnlockingString)
    }

    func refreshFeeIfNeeded() {
        guard fee == nil, controller != nil, payee != nil, bonded != nil, minimalBalance != nil else {
            return
        }

        interactor.estimateFee(
            for: inputAmount,
            resettingRewardDestination: shouldResetRewardDestination,
            chilling: shouldChill
        )
    }

    init(
        interactor: StakingUnbondConfirmInteractorInputProtocol,
        wireframe: StakingUnbondConfirmWireframeProtocol,
        inputAmount: Decimal,
        confirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.inputAmount = inputAmount
        self.confirmViewModelFactory = confirmViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
        self.chain = chain
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

extension StakingUnbondConfirmPresenter: StakingUnbondConfirmPresenterProtocol {
    func setup() {
        provideConfirmationViewModel()
        provideAmountViewModel()
        provideFeeViewModel()
        provideShouldResetRewardsDestination()

        interactor.setup()
    }

    func confirm() {
        let locale = localizationManager.selectedLocale
        DataValidationRunner(validators: [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, asset: assetInfo, locale: locale),

            dataValidatingFactory.has(
                controller: controller?.chainAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(
                for: strongSelf.inputAmount,
                resettingRewardDestination: strongSelf.shouldResetRewardDestination,
                chilling: strongSelf.shouldChill
            )
        }
    }

    func selectAccount() {
        guard let view = view, let address = stashItem?.controller else { return }

        let locale = localizationManager.selectedLocale

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: locale
        )
    }
}

extension StakingUnbondConfirmPresenter: StakingUnbondConfirmInteractorOutputProtocol {
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>) {
        switch result {
        case let .success(assetBalance):
            let amountInPlank = assetBalance?.transferable ?? 0

            balance = Decimal.fromSubstrateAmount(
                amountInPlank,
                precision: assetInfo.assetPrecision
            )
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<Staking.Ledger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            if let stakingLedger = stakingLedger {
                bonded = Decimal.fromSubstrateAmount(
                    stakingLedger.active,
                    precision: assetInfo.assetPrecision
                )
            } else {
                bonded = nil
            }

            provideAmountViewModel()
            provideShouldResetRewardsDestination()
            refreshFeeIfNeeded()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAmountViewModel()
            provideFeeViewModel()
            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(feeInfo):
            fee = feeInfo

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimalBalance):
            self.minimalBalance = Decimal.fromSubstrateAmount(
                minimalBalance,
                precision: assetInfo.assetPrecision
            )

            provideAmountViewModel()
            provideShouldResetRewardsDestination()
            refreshFeeIfNeeded()
        case let .failure(error):
            logger?.error("Minimal balance fetching error: \(error)")
        }
    }

    func didReceiveController(result: Result<MetaChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            if let accountItem = accountItem {
                controller = accountItem
            }

            provideConfirmationViewModel()
            refreshFeeIfNeeded()
        case let .failure(error):
            logger?.error("Did receive controller account error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceivePayee(result: Result<Staking.RewardDestinationArg?, Error>) {
        switch result {
        case let .success(payee):
            self.payee = payee

            refreshFeeIfNeeded()

            provideConfirmationViewModel()
            provideShouldResetRewardsDestination()
        case let .failure(error):
            logger?.error("Did receive payee item error: \(error)")
        }
    }

    func didReceiveMinBonded(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minNominatorBonded):
            if let minNominatorBonded = minNominatorBonded {
                self.minNominatorBonded = Decimal.fromSubstrateAmount(
                    minNominatorBonded,
                    precision: assetInfo.assetPrecision
                )
            } else {
                self.minNominatorBonded = nil
            }

            provideShouldResetRewardsDestination()
            refreshFeeIfNeeded()
        case let .failure(error):
            logger?.error("Did receive min bonded error: \(error)")
        }
    }

    func didReceiveNomination(result: Result<Staking.Nomination?, Error>) {
        switch result {
        case let .success(nomination):
            self.nomination = nomination
            refreshFeeIfNeeded()
        case let .failure(error):
            logger?.error("Did receive nomination error: \(error)")
        }
    }

    func didSubmitUnbonding(result: Result<ExtrinsicSubmittedModel, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case let .success(model):
            wireframe.presentExtrinsicSubmission(
                from: view,
                sender: model.sender,
                completionAction: .dismiss,
                locale: localizationManager.selectedLocale
            )
        case let .failure(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: localizationManager.selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveStakingDuration(result: Result<StakingDuration, Error>) {
        switch result {
        case let .success(duration):
            stakingDuration = duration
            provideBondingDuration()
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }
}
