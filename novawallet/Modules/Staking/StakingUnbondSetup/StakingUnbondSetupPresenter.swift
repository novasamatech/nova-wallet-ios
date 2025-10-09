import Foundation
import Foundation_iOS
import BigInt

final class StakingUnbondSetupPresenter {
    weak var view: StakingUnbondSetupViewProtocol?
    let wireframe: StakingUnbondSetupWireframeProtocol
    let interactor: StakingUnbondSetupInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    let logger: LoggerProtocol?
    var assetInfo: AssetBalanceDisplayInfo { chainAsset.assetDisplayInfo }
    let chainAsset: ChainAsset

    private var bonded: Decimal?
    private var balance: Decimal?
    private var inputAmount: Decimal?
    private var minimalBalance: Decimal?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var controller: ChainAccountResponse?
    private var stashItem: StashItem?
    private var stakingDuration: StakingDuration?

    init(
        interactor: StakingUnbondSetupInteractorInputProtocol,
        wireframe: StakingUnbondSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chainAsset = chainAsset
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func provideInputViewModel() {
        let inputView = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
        view?.didReceiveInput(viewModel: inputView)
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

    private func provideAssetViewModel() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount ?? 0.0,
            balance: bonded,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideTransferableViewModel() {
        if let balance = balance {
            let viewModel = balanceViewModelFactory.balanceFromPrice(balance, priceData: priceData)
            view?.didReceiveTransferable(viewModel: viewModel)
        } else {
            view?.didReceiveTransferable(viewModel: nil)
        }
    }

    private func provideBondingDuration() {
        guard let stakingDuration = stakingDuration else {
            return
        }

        view?.didReceiveBonding(duration: stakingDuration.localizableUnlockingString)
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupPresenterProtocol {
    func setup() {
        provideInputViewModel()
        provideFeeViewModel()
        provideTransferableViewModel()
        provideBondingDuration()
        provideAssetViewModel()

        interactor.setup()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let bonded = bonded {
            inputAmount = bonded * Decimal(Double(percentage))
            provideInputViewModel()
            provideAssetViewModel()
        }
    }

    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        provideAssetViewModel()

        if fee == nil {
            interactor.estimateFee()
        }
    }

    func proceed() {
        let locale = localizationManager.selectedLocale

        var unbondAmount = inputAmount

        let bondedAmountInPlank = bonded?.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )
        let minStakeInPlank = minimalBalance?.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )

        let minStakeValidationParams = MinStakeCrossedParams(
            stakedAmountInPlank: bondedAmountInPlank,
            minStake: minStakeInPlank
        ) { [weak self] in
            unbondAmount = self?.bonded
        }

        DataValidationRunner(validators: [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.interactor.estimateFee()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, asset: assetInfo, locale: locale),

            dataValidatingFactory.has(
                controller: controller,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.minStakeNotCrossed(
                for: inputAmount ?? 0,
                params: minStakeValidationParams,
                chainAsset: chainAsset,
                locale: locale
            )
        ]).runValidation { [weak self] in
            if let amount = unbondAmount {
                self?.wireframe.proceed(view: self?.view, amount: amount)
            } else {
                self?.logger?.warning("Missing amount after validation")
            }
        }
    }

    func close() {
        wireframe.close(view: view)
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupInteractorOutputProtocol {
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>) {
        switch result {
        case let .success(assetBalance):
            let amountInPlank = assetBalance?.transferable ?? 0

            balance = Decimal.fromSubstrateAmount(
                amountInPlank,
                precision: assetInfo.assetPrecision
            )

            provideTransferableViewModel()
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

            provideAssetViewModel()
        case let .failure(error):
            logger?.error("Staking ledger subscription error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideAssetViewModel()
            provideFeeViewModel()
            provideTransferableViewModel()
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
        case let .failure(error):
            logger?.error("Minimal balance fetching error: \(error)")
        }
    }

    func didReceiveController(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            if let accountItem = accountItem {
                controller = accountItem
            }
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
