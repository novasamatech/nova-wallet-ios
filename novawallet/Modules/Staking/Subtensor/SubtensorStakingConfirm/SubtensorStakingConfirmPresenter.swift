import BigInt
import Foundation
import Foundation_iOS

final class SubtensorStakingConfirmPresenter {
    weak var view: CollatorStakingConfirmViewProtocol?
    let wireframe: SubtensorStakingConfirmWireframeProtocol
    let interactor: SubtensorStakingConfirmInteractorInputProtocol

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let model: SubtensorStakingConfirmModel
    let logger: LoggerProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol

    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var positionsState: Multistaking.SubtensorStakingState?
    private(set) var preflight: SubtensorStakingPreflight?
    private(set) var existentialDeposit: Balance?
    private(set) var currentBlock: BlockNumber?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()
    private lazy var takeFormatter = NumberFormatter.percentSingle.localizableResource()

    init(
        interactor: SubtensorStakingConfirmInteractorInputProtocol,
        wireframe: SubtensorStakingConfirmWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        model: SubtensorStakingConfirmModel,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.model = model
        self.dataValidationFactory = dataValidationFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension SubtensorStakingConfirmPresenter {
    func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            model.stakeModel.amount.decimal(assetInfo: chainAsset.assetDisplayInfo),
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

    func provideHintsViewModel() {
        let languages = selectedLocale.rLanguages

        var hints = [
            R.string(preferredLanguages: languages).localizable.stakingSubtensorHintManualClaim()
        ]

        if
            let take = model.delegateTake ?? preflight?.delegateTake,
            let takeString = takeFormatter.value(for: selectedLocale).stringFromDecimal(
                Decimal(take) / Decimal(UInt16.max)
            ) {
            hints.append(
                R.string(preferredLanguages: languages).localizable.stakingSubtensorHintTakeFormat(
                    takeString
                )
            )
        }

        view?.didReceiveHints(viewModel: hints)
    }

    func refreshFee() {
        fee = nil
        provideFeeViewModel()

        interactor.estimateFee(for: .stake(model.stakeModel))
    }

    func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideDelegateViewModel()
        provideHintsViewModel()
    }

    func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chainAsset.chain,
            locale: selectedLocale
        )
    }

    func getValidationDependencies() -> SubtensorStakeValidatingDep {
        SubtensorStakeValidatingDep(
            amount: model.stakeModel.amount,
            balance: balance,
            fee: fee,
            existentialDeposit: existentialDeposit,
            preflight: preflight,
            netuid: model.stakeModel.netuid,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            onFeeRefresh: { [weak self] in
                self?.refreshFee()
            },
            onPreflightRefresh: { [weak self] in
                guard let self else {
                    return
                }

                interactor.refreshPreflight(for: model.stakeModel.hotkey)
            }
        )
    }

    func createSuccessTitle(
        for submission: SubtensorSubmissionModel
    ) -> ExtrinsicSubmissionPresentingParams.Title {
        guard case let .staked(tao) = submission.outcome, tao > 0 else {
            return .general(selectedLocale)
        }

        let amountDecimal = tao.decimal(assetInfo: chainAsset.assetDisplayInfo)
        let amountString = balanceViewModelFactory.amountFromValue(
            amountDecimal
        ).value(for: selectedLocale)

        let title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingSubtensorSuccessStakedFormat(amountString)

        return .preferred(title)
    }
}

extension SubtensorStakingConfirmPresenter: CollatorStakingConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()

        interactor.refreshPreflight(for: model.stakeModel.hotkey)

        refreshFee()
    }

    func selectAccount() {
        guard let address = selectedAccount.chainAccount.toAddress() else {
            return
        }

        presentOptions(for: address)
    }

    func selectCollator() {
        presentOptions(for: model.delegate.address)
    }

    func confirm() {
        validateStake(
            for: getValidationDependencies(),
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        ) { [weak self] in
            guard let self else {
                return
            }

            view?.didStartLoading()

            interactor.submit(call: .stake(model.stakeModel))
        }
    }
}

extension SubtensorStakingConfirmPresenter: SubtensorStakePresenterValidating {}

extension SubtensorStakingConfirmPresenter: SubtensorStakingConfirmInteractorOutputProtocol {
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
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        logger.debug("Claimable: \(String(describing: claimable))")
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        logger.debug("Block number: \(blockNumber)")

        currentBlock = blockNumber
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        logger.debug("Preflight: \(preflight)")

        self.preflight = preflight

        provideHintsViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        logger.debug("Existential deposit: \(deposit)")

        existentialDeposit = deposit
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

                interactor.refreshPreflight(for: model.stakeModel.hotkey)
            }
        }
    }
}

extension SubtensorStakingConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
