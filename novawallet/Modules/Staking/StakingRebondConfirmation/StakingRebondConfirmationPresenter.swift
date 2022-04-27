import Foundation
import BigInt

final class StakingRebondConfirmationPresenter {
    weak var view: StakingRebondConfirmationViewProtocol?
    let wireframe: StakingRebondConfirmationWireframeProtocol
    let interactor: StakingRebondConfirmationInteractorInputProtocol

    let variant: SelectedRebondVariant
    let confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let explorers: [ChainModel.Explorer]?
    let logger: LoggerProtocol?

    var inputAmount: Decimal? {
        switch variant {
        case .all:
            if let ledger = stakingLedger {
                let value = ledger.unbonding()
                return Decimal.fromSubstrateAmount(value, precision: assetInfo.assetPrecision)
            } else {
                return nil
            }
        case .last:
            if let ledger = stakingLedger, let chunk = ledger.unlocking.last {
                return Decimal.fromSubstrateAmount(chunk.value, precision: assetInfo.assetPrecision)
            } else {
                return nil
            }
        case let .custom(amount):
            return amount
        }
    }

    var unbonding: Decimal? {
        if let value = stakingLedger?.unbonding() {
            return Decimal.fromSubstrateAmount(value, precision: assetInfo.assetPrecision)
        } else {
            return nil
        }
    }

    private var stakingLedger: StakingLedger?
    private var balance: Decimal?
    private var priceData: PriceData?
    private var fee: Decimal?
    private var controller: MetaChainAccountResponse?
    private var stashItem: StashItem?

    init(
        variant: SelectedRebondVariant,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        explorers: [ChainModel.Explorer]?,
        logger: LoggerProtocol? = nil
    ) {
        self.variant = variant
        self.interactor = interactor
        self.wireframe = wireframe
        self.confirmViewModelFactory = confirmViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
        self.explorers = explorers
        self.logger = logger
    }

    private func provideFeeViewModel() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAmountViewModel() {
        guard let inputAmount = inputAmount else {
            return
        }

        let viewModel = balanceViewModelFactory.lockingAmountFromPrice(inputAmount, priceData: priceData)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideConfirmationViewModel() {
        guard let controller = controller else {
            return
        }

        do {
            let viewModel = try confirmViewModelFactory.createViewModel(controllerItem: controller)

            view?.didReceiveConfirmation(viewModel: viewModel)
        } catch {
            logger?.error("Did receive view model factory error: \(error)")
        }
    }

    func refreshFeeIfNeeded() {
        guard fee == nil, let amount = inputAmount else {
            return
        }

        interactor.estimateFee(for: amount)
    }
}

extension StakingRebondConfirmationPresenter: StakingRebondConfirmationPresenterProtocol {
    func setup() {
        provideConfirmationViewModel()
        provideAmountViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func confirm() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.canRebond(amount: inputAmount, unbonding: unbonding, locale: locale),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, locale: locale),

            dataValidatingFactory.has(
                controller: controller?.chainAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self, let inputAmount = self?.inputAmount else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(for: inputAmount)
        }
    }

    func selectAccount() {
        guard let view = view, let address = stashItem?.controller else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: explorers,
            locale: locale
        )
    }
}

extension StakingRebondConfirmationPresenter: StakingRebondConfirmationInteractorOutputProtocol {
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
            self.stakingLedger = stakingLedger

            provideConfirmationViewModel()
            provideAmountViewModel()
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

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                self.fee = Decimal.fromSubstrateAmount(fee, precision: assetInfo.assetPrecision)
            } else {
                fee = nil
            }

            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Did receive fee error: \(error)")
        }
    }

    func didReceiveController(result: Result<MetaChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            controller = accountItem

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

    func didSubmitRebonding(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case .failure:
            wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
        }
    }
}
