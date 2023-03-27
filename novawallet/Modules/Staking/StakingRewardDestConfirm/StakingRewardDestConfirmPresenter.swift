import Foundation
import BigInt

final class StakingRewardDestConfirmPresenter {
    weak var view: StakingRewardDestConfirmViewProtocol?
    let wireframe: StakingRewardDestConfirmWireframeProtocol
    let interactor: StakingRewardDestConfirmInteractorInputProtocol
    let rewardDestination: RewardDestination<MetaChainAccountResponse>
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let confirmModelFactory: StakingRewardDestConfirmVMFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo
    let chain: ChainModel
    let logger: LoggerProtocol?

    private var controllerAccount: MetaChainAccountResponse?
    private var stashItem: StashItem?
    private var fee: Decimal?
    private var balance: Decimal?
    private var priceData: PriceData?

    init(
        interactor: StakingRewardDestConfirmInteractorInputProtocol,
        wireframe: StakingRewardDestConfirmWireframeProtocol,
        rewardDestination: RewardDestination<MetaChainAccountResponse>,
        confirmModelFactory: StakingRewardDestConfirmVMFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.rewardDestination = rewardDestination
        self.confirmModelFactory = confirmModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.assetInfo = assetInfo
        self.chain = chain
        self.logger = logger
    }

    private func provideFeeViewModel() {
        let viewModel = fee.map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData) }
        view?.didReceiveFee(viewModel: viewModel)
    }

    private func provideConfirmationViewModel() {
        guard let controller = controllerAccount else {
            return
        }

        do {
            let viewModel = try confirmModelFactory.createViewModel(
                rewardDestination: rewardDestination,
                controller: controller
            )

            view?.didReceiveConfirmation(viewModel: viewModel)
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func refreshFeeIfNeeded() {
        guard fee == nil, let stashItem = stashItem, let address = rewardDestination.accountAddress else {
            return
        }

        interactor.estimateFee(for: address, stashItem: stashItem)
    }
}

extension StakingRewardDestConfirmPresenter: StakingRewardDestConfirmPresenterProtocol {
    func setup() {
        provideFeeViewModel()
        provideConfirmationViewModel()

        interactor.setup()
    }

    func confirm() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount?.chainAccount,
                for: stashItem?.controller ?? "",
                locale: locale
            ),

            dataValidatingFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFeeIfNeeded()
            }),

            dataValidatingFactory.canPayFee(balance: balance, fee: fee, asset: assetInfo, locale: locale)

        ]).runValidation { [weak self] in
            guard
                let rewardDestination = self?.rewardDestination,
                let stashItem = self?.stashItem,
                let address = rewardDestination.accountAddress
            else { return }

            self?.view?.didStartLoading()

            self?.interactor.submit(rewardDestination: address, for: stashItem)
        }
    }

    func presentSenderAccountOptions() {
        guard
            let address = controllerAccount?.chainAccount.toAddress(),
            let view = view,
            let locale = view.localizationManager?.selectedLocale else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: locale
        )
    }

    func presentPayoutAccountOptions() {
        guard
            let address = rewardDestination.payoutAccount?.chainAccount.toAddress(),
            let view = view,
            let locale = view.localizationManager?.selectedLocale else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: locale
        )
    }
}

extension StakingRewardDestConfirmPresenter: StakingRewardDestConfirmInteractorOutputProtocol {
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

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem

            refreshFeeIfNeeded()

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive stash item error: \(error)")
        }
    }

    func didReceiveController(result: Result<MetaChainAccountResponse?, Error>) {
        switch result {
        case let .success(controller):
            controllerAccount = controller

            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive controller error: \(error)")
        }
    }

    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>) {
        switch result {
        case let .success(assetBalance):
            balance = assetBalance.map {
                Decimal.fromSubstrateAmount($0.transferable, precision: assetInfo.assetPrecision)
            } ?? nil
        case let .failure(error):
            logger?.error("Did receive balance error: \(error)")
        }
    }

    func didSubmitRewardDest(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case let .failure(error):
            if error.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else if error.isHardwareWalletSigningCancelled {
                return
            } else {
                wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
            }
        }
    }
}
