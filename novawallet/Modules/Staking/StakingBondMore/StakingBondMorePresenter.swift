import SoraFoundation
import CommonWallet
import BigInt

final class StakingBondMorePresenter {
    let interactor: StakingBondMoreInteractorInputProtocol
    let wireframe: StakingBondMoreWireframeProtocol
    weak var view: StakingBondMoreViewProtocol?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let logger: LoggerProtocol?

    var amount: Decimal = 0
    private let assetInfo: AssetBalanceDisplayInfo
    private var priceData: PriceData?
    private var freeBalance: Decimal?
    private var transferableBalance: Decimal?
    private var bondBalance: Decimal?
    private var fee: Decimal?
    private var stashItem: StashItem?
    private var stashAccount: ChainAccountResponse?

    private var availableAmountToStake: Decimal? {
        let free = freeBalance ?? 0
        let bond = bondBalance ?? 0

        return free >= bond ? free - bond : 0
    }

    init(
        interactor: StakingBondMoreInteractorInputProtocol,
        wireframe: StakingBondMoreWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
        self.logger = logger
    }

    private func estimateFee() {
        guard fee == nil else {
            return
        }

        interactor.estimateFee()
    }

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    private func provideFee() {
        if let fee = fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            amount,
            balance: availableAmountToStake,
            priceData: priceData
        )
        view?.didReceiveAsset(viewModel: viewModel)
    }
}

extension StakingBondMorePresenter: StakingBondMorePresenterProtocol {
    func setup() {
        provideAmountInputViewModel()

        interactor.setup()
    }

    func handleContinueAction() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.interactor.estimateFee()
            }),

            dataValidatingFactory.canSpendAmount(
                balance: availableAmountToStake,
                spendingAmount: amount,
                locale: locale
            ),

            dataValidatingFactory.canPayFee(
                balance: transferableBalance,
                fee: fee,
                asset: assetInfo,
                locale: locale
            ),

            dataValidatingFactory.canPayFeeSpendingAmount(
                balance: availableAmountToStake,
                fee: fee,
                spendingAmount: amount,
                asset: assetInfo,
                locale: locale
            ),

            dataValidatingFactory.has(
                stash: stashAccount,
                for: stashItem?.stash ?? "",
                locale: locale
            )

        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.wireframe.showConfirmation(from: strongSelf.view, amount: strongSelf.amount)
        }
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        provideAsset()
        estimateFee()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = availableAmountToStake, let fee = fee {
            let newAmount = max(balance - fee, 0.0) * Decimal(Double(percentage))

            if newAmount > 0 {
                amount = newAmount

                provideAmountInputViewModel()
                provideAsset()
            } else if let view = view {
                wireframe.presentAmountTooHigh(
                    from: view,
                    locale: view.localizationManager?.selectedLocale
                )
            }
        }
    }
}

extension StakingBondMorePresenter: StakingBondMoreInteractorOutputProtocol {
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
                freeBalance = nil
                transferableBalance = nil
            }

            provideAsset()
        case let .failure(error):
            logger?.error("Did receive account info error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(ledger):
            if let ledger = ledger {
                bondBalance = Decimal.fromSubstrateAmount(
                    ledger.total,
                    precision: assetInfo.assetPrecision
                )
            } else {
                bondBalance = nil
            }
        case let .failure(error):
            logger?.error("Did receive staking ledger error: \(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAsset()
            provideFee()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let feeValue = BigUInt(dispatchInfo.fee) {
                fee = Decimal.fromSubstrateAmount(feeValue, precision: assetInfo.assetPrecision)
            } else {
                fee = nil
            }

            provideFee()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveStash(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(stashAccount):
            self.stashAccount = stashAccount
        case let .failure(error):
            logger?.error("Did receive stash account error: \(error)")
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
}
