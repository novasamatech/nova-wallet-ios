import Foundation
import BigInt

final class StakingRedeemPresenter {
    weak var view: StakingRedeemViewProtocol?
    let wireframe: StakingRedeemWireframeProtocol
    let interactor: StakingRedeemInteractorInputProtocol

    let confirmViewModelFactory: StakingRedeemViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let chain: ChainModel
    let logger: LoggerProtocol?

    private var stakingLedger: StakingLedger?
    private var activeEra: UInt32?
    private var balance: Decimal?
    private var minimalBalance: BigUInt?
    private var priceData: PriceData?
    private var fee: ExtrinsicFeeProtocol?
    private var controller: MetaChainAccountResponse?
    private var stashItem: StashItem?

    init(
        interactor: StakingRedeemInteractorInputProtocol,
        wireframe: StakingRedeemWireframeProtocol,
        confirmViewModelFactory: StakingRedeemViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.confirmViewModelFactory = confirmViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
        self.chain = chain
        self.logger = logger
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
        guard
            let era = activeEra,
            let redeemable = stakingLedger?.redeemable(inEra: era),
            let redeemableDecimal = Decimal.fromSubstrateAmount(
                redeemable,
                precision: assetInfo.assetPrecision
            ) else {
            return
        }

        let viewModel = balanceViewModelFactory.lockingAmountFromPrice(redeemableDecimal, priceData: priceData)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideConfirmationViewModel() {
        guard let controller = controller else {
            return
        }

        do {
            let viewModel = try confirmViewModelFactory.createRedeemViewModel(controllerItem: controller)

            view?.didReceiveConfirmation(viewModel: viewModel)
        } catch {
            logger?.error("Did receive view model factory error: \(error)")
        }
    }

    func refreshFeeIfNeeded() {
        guard
            fee == nil,
            controller != nil,
            stakingLedger != nil,
            minimalBalance != nil,
            let stashItem = stashItem else {
            return
        }

        interactor.estimateFeeForStash(stashItem.stash)
    }
}

extension StakingRedeemPresenter: StakingRedeemPresenterProtocol {
    func setup() {
        provideConfirmationViewModel()
        provideAssetViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func confirm() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.hasRedeemable(
                stakingLedger: stakingLedger,
                in: activeEra,
                locale: locale
            ),

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
            guard let strongSelf = self, let stashItem = self?.stashItem else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submitForStash(stashItem.stash)
        }
    }

    func selectAccount() {
        guard let view = view, let address = stashItem?.controller else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: locale
        )
    }
}

extension StakingRedeemPresenter: StakingRedeemInteractorOutputProtocol {
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
        case let .failure(error):
            logger?.error("Account Info subscription error: \(error)")
        }
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        switch result {
        case let .success(stakingLedger):
            self.stakingLedger = stakingLedger

            provideConfirmationViewModel()
            provideAssetViewModel()
            refreshFeeIfNeeded()
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
            self.minimalBalance = minimalBalance

            provideAssetViewModel()
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

    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>) {
        switch result {
        case let .success(eraInfo):
            activeEra = eraInfo?.index

            provideAssetViewModel()
            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive active era error: \(error)")
        }
    }

    func didSubmitRedeeming(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case let .failure(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: view.localizationManager?.selectedLocale,
                completionClosure: nil
            )
        }
    }
}
