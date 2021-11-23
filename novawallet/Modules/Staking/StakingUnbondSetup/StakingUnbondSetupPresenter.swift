import Foundation
import SoraFoundation
import BigInt

final class StakingUnbondSetupPresenter {
    weak var view: StakingUnbondSetupViewProtocol?
    let wireframe: StakingUnbondSetupWireframeProtocol
    let interactor: StakingUnbondSetupInteractorInputProtocol

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    let logger: LoggerProtocol?
    let assetInfo: AssetBalanceDisplayInfo

    private var bonded: Decimal?
    private var balance: Decimal?
    private var inputAmount: Decimal?
    private var bondingDuration: UInt32?
    private var minimalBalance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var controller: AccountItem?
    private var stashItem: StashItem?
    private var stakingDuration: StakingDuration?

    init(
        interactor: StakingUnbondSetupInteractorInputProtocol,
        wireframe: StakingUnbondSetupWireframeProtocol,
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

    private func provideInputViewModel() {
        let inputView = balanceViewModelFactory.createBalanceInputViewModel(inputAmount)
        view?.didReceiveInput(viewModel: inputView)
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
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

    private func provideBondingDuration() {
        guard let erasPerDay = stakingDuration?.era.intervalsInDay else {
            return
        }

        let daysCount = bondingDuration.map { erasPerDay > 0 ? Int($0) / erasPerDay : 0 }
        let bondingDuration: LocalizableResource<String> = LocalizableResource { locale in
            guard let daysCount = daysCount else {
                return ""
            }

            return R.string.localizable.commonDaysFormat(
                format: daysCount,
                preferredLanguages: locale.rLanguages
            )
        }

        view?.didReceiveBonding(duration: bondingDuration)
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupPresenterProtocol {
    func setup() {
        provideInputViewModel()
        provideFeeViewModel()
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
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.canUnbond(amount: inputAmount, bonded: bonded, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.interactor.estimateFee()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.has(
                controller: controller,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.stashIsNotKilledAfterUnbonding(
                amount: inputAmount,
                bonded: bonded,
                minimumAmount: minimalBalance,
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
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupInteractorOutputProtocol {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(accountInfo):
            if let accountInfo = accountInfo {
                balance = Decimal.fromSubstrateAmount(
                    accountInfo.data.available,
                    precision: assetInfo.assetPrecision
                )
            } else {
                balance = nil
            }
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
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
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: assetInfo.assetPrecision)
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveBondingDuration(result: Result<UInt32, Error>) {
        switch result {
        case let .success(bondingDuration):
            self.bondingDuration = bondingDuration
            provideBondingDuration()
        case let .failure(error):
            logger?.error("Boding duration fetching error: \(error)")
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

    func didReceiveController(result: Result<AccountItem?, Error>) {
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
