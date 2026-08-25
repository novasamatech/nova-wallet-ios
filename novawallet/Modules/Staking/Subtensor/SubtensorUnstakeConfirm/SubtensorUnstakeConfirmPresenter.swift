import BigInt
import Foundation
import Foundation_iOS

final class SubtensorUnstakeConfirmPresenter {
    weak var view: CollatorStkUnstakeConfirmViewProtocol?
    let wireframe: SubtensorUnstakeConfirmWireframeProtocol
    let interactor: SubtensorUnstakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let model: SubtensorUnstakeConfirmModel
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var positionsState: Multistaking.SubtensorStakingState?
    private(set) var claimable: SubtensorRootClaimable?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var currentBlock: BlockNumber?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorUnstakeConfirmInteractorInputProtocol,
        wireframe: SubtensorUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        model: SubtensorUnstakeConfirmModel,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.model = model
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension SubtensorUnstakeConfirmPresenter {
    func stakedAmountInPlank() -> Balance {
        let positions = positionsState?.positions ?? []

        return positions.first {
            $0.netuid == model.unstakeModel.netuid && $0.hotkey == model.unstakeModel.hotkey
        }?.stakeAlpha ?? model.unstakeModel.amount
    }

    func unstakingAmount() -> Balance {
        model.unstakeModel.isFullUnstake ? stakedAmountInPlank() : model.unstakeModel.amount
    }

    func provideAmountViewModel() {
        let amountDecimal = unstakingAmount().decimal(assetInfo: chainAsset.assetDisplayInfo)

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amountDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.map { value in
            let amountDecimal = value.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale).approximatelyForSubtensorFee()
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideDelegateViewModel() {
        let viewModel = displayAddressViewModelFactory.createViewModel(from: model.delegate)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    func provideHints() {
        let hints = [
            R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingSubtensorHintUnstakeInstant()
        ]

        view?.didReceiveHints(viewModel: hints)
    }

    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        interactor.estimateFee(for: .unstake(model.unstakeModel))
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideDelegateViewModel()
        provideHints()
    }

    func getValidationDependencies() -> SubtensorUnstakeValidatingDep {
        SubtensorUnstakeValidatingDep(
            amount: unstakingAmount(),
            stakedAmount: stakedAmountInPlank(),
            isFullUnstake: model.unstakeModel.isFullUnstake,
            balance: balance,
            fee: fee,
            preflight: preflight,
            claimablePayout: claimable?.payout(for: model.unstakeModel.hotkey),
            currentBlock: currentBlock,
            blockTime: chainAsset.chain.defaultBlockTimeMillis ?? SubtensorStakingFlowConstants.blockTimeMillis,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                guard let self else {
                    return
                }

                interactor.refreshPreflight(for: model.unstakeModel.hotkey)
            }
        )
    }

    func createSuccessTitle(
        for submission: SubtensorSubmissionModel
    ) -> ExtrinsicSubmissionPresentingParams.Title {
        guard case let .unstaked(tao) = submission.outcome, tao > 0 else {
            return .general(selectedLocale)
        }

        let amountDecimal = tao.decimal(assetInfo: chainAsset.assetDisplayInfo)
        let amountString = balanceViewModelFactory.amountFromValue(
            amountDecimal
        ).value(for: selectedLocale)

        let title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorSuccessUnstakedFormat(amountString)

        return .preferred(title)
    }
}

extension SubtensorUnstakeConfirmPresenter: CollatorStkUnstakeConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()

        interactor.refreshPreflight(for: model.unstakeModel.hotkey)

        refreshFee()
    }

    func selectAccount() {
        guard
            let address = selectedAccount.chainAccount.toAddress(),
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func selectCollator() {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: model.delegate.address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func confirm() {
        validateUnstake(
            for: getValidationDependencies(),
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            guard let self else {
                return
            }

            view?.didStartLoading()

            interactor.submit(call: .unstake(model.unstakeModel))
        }
    }
}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakePresenterValidating {}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakeConfirmInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<SubtensorSubmissionModel, Error>) {
        view?.didStopLoading()

        switch result {
        case let .success(submission):
            wireframe.complete(
                on: view,
                sender: submission.submitted.sender,
                title: createSuccessTitle(for: submission)
            )
        case let .failure(error):
            logger.error("Submission error: \(error)")

            applyCurrentState()
            refreshFee()

            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        logger.debug("Balance: \(String(describing: balance))")

        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        logger.debug("Price: \(String(describing: priceData))")

        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideFeeViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        logger.debug("Positions: \(String(describing: state))")

        positionsState = state

        provideAmountViewModel()
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")

        self.claimable = claimable
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        self.preflight = preflight
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

        switch error {
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .preflightFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                guard let self else {
                    return
                }

                interactor.refreshPreflight(for: model.unstakeModel.hotkey)
            }
        }
    }
}

extension SubtensorUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applyCurrentState()
        }
    }
}
