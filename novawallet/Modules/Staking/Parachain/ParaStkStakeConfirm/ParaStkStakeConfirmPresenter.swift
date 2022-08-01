import Foundation
import BigInt
import SoraFoundation

final class ParaStkStakeConfirmPresenter {
    weak var view: ParaStkStakeConfirmViewProtocol?
    let wireframe: ParaStkStakeConfirmWireframeProtocol
    let interactor: ParaStkStakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let dataValidatingFactory: ParaStkValidatorFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let collator: DisplayAddress
    let amount: Decimal
    let logger: LoggerProtocol

    private(set) var balance: AssetBalance?
    private(set) var fee: BigUInt?
    private(set) var price: PriceData?
    private(set) var stakingDuration: ParachainStakingDuration?
    private(set) var delegator: ParachainStaking.Delegator?
    private(set) var collatorMetadata: ParachainStaking.CandidateMetadata?
    private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    private(set) var minTechStake: BigUInt?
    private(set) var minDelegationAmount: BigUInt?
    private(set) var maxDelegations: UInt32?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: ParaStkStakeConfirmInteractorInputProtocol,
        wireframe: ParaStkStakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        dataValidatingFactory: ParaStkValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: ParachainStaking.Delegator?,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.dataValidatingFactory = dataValidatingFactory
        self.selectedAccount = selectedAccount
        self.balanceViewModelFactory = balanceViewModelFactory
        delegator = initialDelegator
        self.collator = collator
        self.amount = amount
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func existingStakeInPlank() -> BigUInt? {
        if let collatorId = try? collator.address.toAccountId() {
            return delegator?.delegations.first(where: { $0.owner == collatorId })?.amount
        } else {
            return nil
        }
    }

    private func provideAmountViewModel() {
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAmount(viewModel: viewModel)
    }

    private func provideWalletViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createDisplayViewModel(from: selectedAccount)
            view?.didReceiveWallet(viewModel: viewModel)
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    private func provideAccountViewModel() {
        do {
            let viewModel = try walletViewModelFactory.createViewModel(from: selectedAccount)
            view?.didReceiveAccount(viewModel: viewModel.rawDisplayAddress())
        } catch {
            logger.error("Did receive error: \(error)")
        }
    }

    private func provideFeeViewModel() {
        let viewModel: BalanceViewModelProtocol? = fee.flatMap { amount in
            guard let amountDecimal = Decimal.fromSubstrateAmount(
                amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) else {
                return nil
            }

            return balanceViewModelFactory.balanceFromPrice(
                amountDecimal,
                priceData: price
            ).value(for: selectedLocale)
        }

        view?.didReceiveFee(viewModel: viewModel)
    }

    private func provideCollatorViewModel() {
        let viewModel = displayAddressViewModelFactory.createViewModel(from: collator)
        view?.didReceiveCollator(viewModel: viewModel)
    }

    private func provideHintsViewModel() {
        if delegator != nil {
            provideStakeMoreHintsViewModel()
        } else {
            provideStartStakingHintsViewModel()
        }
    }

    private func presentOptions(for address: AccountAddress) {
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

    func refreshFee() {
        guard
            let amountInPlank = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision),
            let collatorId = try? collator.address.toAccountId() else {
            return
        }

        let collatorDelegationsCount = collatorMetadata?.delegationCount ?? 0
        let delegationsCount = delegator?.delegations.count ?? 0

        fee = nil

        let callWrapper = DelegationCallWrapper(
            amount: amountInPlank,
            collator: collatorId,
            collatorDelegationsCount: collatorDelegationsCount,
            delegationsCount: UInt32(delegationsCount),
            existingBond: existingStakeInPlank()
        )

        interactor.estimateFee(with: callWrapper)

        provideFeeViewModel()
    }

    func submitExtrinsic() {
        guard
            let amountInPlank = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision),
            let collatorId = try? collator.address.toAccountId(),
            let collatorDelegationsCount = collatorMetadata?.delegationCount else {
            return
        }

        let delegationsCount = delegator?.delegations.count ?? 0

        view?.didStartLoading()

        let callWrapper = DelegationCallWrapper(
            amount: amountInPlank,
            collator: collatorId,
            collatorDelegationsCount: collatorDelegationsCount,
            delegationsCount: UInt32(delegationsCount),
            existingBond: existingStakeInPlank()
        )

        interactor.confirm(with: callWrapper)
    }

    private func applyCurrentState() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideCollatorViewModel()
        provideHintsViewModel()
    }
}

extension ParaStkStakeConfirmPresenter: ParaStkStakeConfirmPresenterProtocol {
    func setup() {
        applyCurrentState()

        interactor.setup()
    }

    func selectAccount() {
        let chainFormat = chainAsset.chain.chainFormat

        guard let address = try? selectedAccount.chainAccount.accountId.toAddress(using: chainFormat) else {
            return
        }

        presentOptions(for: address)
    }

    func selectCollator() {
        presentOptions(for: collator.address)
    }

    func confirm() {
        if let existingAmount = existingStakeInPlank() {
            stakeMore(above: existingAmount)
        } else {
            startStaking()
        }
    }
}

extension ParaStkStakeConfirmPresenter: ParaStkStakeConfirmInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAmountViewModel()
        provideFeeViewModel()
    }

    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            fee = BigUInt(dispatchInfo.fee)

            provideFeeViewModel()
        case let .failure(error):
            logger.error("Did receive error: \(error)")

            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        }
    }

    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?) {
        collatorMetadata = metadata

        if !interactor.hasPendingExtrinsic {
            refreshFee()
        }
    }

    func didReceiveMinTechStake(_ minStake: BigUInt) {
        minTechStake = minStake
    }

    func didReceiveMinDelegationAmount(_ amount: BigUInt) {
        minDelegationAmount = amount
    }

    func didReceiveMaxDelegations(_ maxDelegations: UInt32) {
        self.maxDelegations = maxDelegations
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator

        if !interactor.hasPendingExtrinsic {
            refreshFee()
            provideHintsViewModel()
        }
    }

    func didReceiveStakingDuration(_ duration: ParachainStakingDuration) {
        stakingDuration = duration

        if !interactor.hasPendingExtrinsic {
            provideHintsViewModel()
        }
    }

    func didCompleteExtrinsicSubmission(for result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            wireframe.complete(on: view, locale: selectedLocale)
        case let .failure(error):
            applyCurrentState()
            refreshFee()

            if error.isWatchOnlySigning {
                wireframe.presentDismissingNoSigningView(from: view)
            } else {
                _ = wireframe.present(error: error, from: view, locale: selectedLocale)

                logger.error("Extrinsic submission failed: \(error)")
            }
        }
    }

    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
        self.scheduledRequests = scheduledRequests
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension ParaStkStakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAmountViewModel()
            provideFeeViewModel()
            provideHintsViewModel()
        }
    }
}
