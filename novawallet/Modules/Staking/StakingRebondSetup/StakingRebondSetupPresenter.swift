import Foundation
import Foundation_iOS
import BigInt

final class StakingRebondSetupPresenter {
    weak var view: StakingRebondSetupViewProtocol?
    let wireframe: StakingRebondSetupWireframeProtocol!
    let interactor: StakingRebondSetupInteractorInputProtocol!

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol?

    private var inputAmount: Decimal?
    private var balance: Decimal?
    private var fee: ExtrinsicFeeProtocol?
    private var priceData: PriceData?
    private var stashItem: StashItem?
    private var controller: ChainAccountResponse?
    private var stakingLedger: StakingLedger?

    var unbonding: Decimal? {
        if let value = stakingLedger?.unbonding() {
            return Decimal.fromSubstrateAmount(value, precision: assetInfo.assetPrecision)
        } else {
            return nil
        }
    }

    init(
        wireframe: StakingRebondSetupWireframeProtocol,
        interactor: StakingRebondSetupInteractorInputProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
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
        guard let unbonding = unbonding else {
            return
        }

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount ?? 0.0,
            balance: unbonding,
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
}

extension StakingRebondSetupPresenter: StakingRebondSetupPresenterProtocol {
    func selectAmountPercentage(_ percentage: Float) {
        if let unbonding = unbonding {
            inputAmount = unbonding * Decimal(Double(percentage))
            provideInputViewModel()
            provideAssetViewModel()
        }
    }

    func updateAmount(_ amount: Decimal) {
        inputAmount = amount
        provideAssetViewModel()
    }

    func proceed() {
        let locale = localizationManager.selectedLocale
        DataValidationRunner(validators: [
            dataValidatingFactory.canRebond(amount: inputAmount, unbonding: unbonding, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.interactor.estimateFee()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, asset: assetInfo, locale: locale),

            dataValidatingFactory.has(
                controller: controller,
                for: stashItem?.controller ?? "",
                locale: locale
            )
        ]).runValidation { [weak self] in
            if let amount = self?.inputAmount {
                self?.wireframe.proceed(view: self?.view, amount: amount)
            } else {
                self?.logger?.warning("Missing amount after validation")
            }
        }
    }

    func close() {
        wireframe.close(view: view)
    }

    func setup() {
        provideInputViewModel()
        provideFeeViewModel()
        provideAssetViewModel()
        provideTransferableViewModel()

        interactor.setup()
    }
}

extension StakingRebondSetupPresenter: StakingRebondSetupInteractorOutputProtocol {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(feeInfo):
            fee = feeInfo

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger
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

    func didReceiveController(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            controller = accountItem
        case let .failure(error):
            logger?.error("Received controller account error: \(error)")
        }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem
        case let .failure(error):
            logger?.error("Received stash item error: \(error)")
        }
    }

    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>) {
        switch result {
        case let .success(assetBalance):
            if let assetBalance = assetBalance {
                balance = Decimal.fromSubstrateAmount(
                    assetBalance.transferable,
                    precision: assetInfo.assetPrecision
                )
            } else {
                balance = nil
            }

            provideTransferableViewModel()
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }
}
