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

    private var balance: AssetBalance?
    private var fee: BigUInt?
    private var price: PriceData?
    private var stakingDuration: ParachainStakingDuration?
    private var delegator: ParachainStaking.Delegator?
    private var collatorMetadata: ParachainStaking.CandidateMetadata?
    private var minTechStake: BigUInt?

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
        var hints: [String] = []
        let languages = selectedLocale.rLanguages

        if let stakingDuration = stakingDuration {
            let roundDuration = stakingDuration.round.localizedDaysHours(for: selectedLocale)
            let unstakingPeriod = stakingDuration.unstaking.localizedDaysHours(for: selectedLocale)

            hints.append(contentsOf: [
                R.string.localizable.parachainStakingHintRewardsFormat(
                    "~\(roundDuration)",
                    preferredLanguages: languages
                ),
                R.string.localizable.stakingHintUnstakeFormat_v2_2_0(
                    "~\(unstakingPeriod)",
                    preferredLanguages: languages
                )
            ])
        }

        hints.append(contentsOf: [
            R.string.localizable.stakingHintNoRewards_V2_2_0(preferredLanguages: languages),
            R.string.localizable.stakingHintRedeem_v2_2_0(preferredLanguages: languages)
        ])

        view?.didReceiveHints(viewModel: hints)
    }

    private func presentOptions(for address: AccountAddress) {
        guard let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            explorers: chainAsset.chain.explorers,
            locale: selectedLocale
        )
    }

    private func refreshFee() {
        guard
            let amountInPlank = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision),
            let collatorId = try? collator.address.toAccountId() else {
            return
        }

        let collatorDelegationsCount = collatorMetadata?.delegationCount ?? 0
        let delegationsCount = delegator?.delegations.count ?? 0

        fee = nil

        interactor.estimateFee(
            amountInPlank,
            collator: collatorId,
            collatorDelegationsCount: collatorDelegationsCount,
            delegationsCount: UInt32(delegationsCount),
            existingBond: existingStakeInPlank()
        )

        provideFeeViewModel()
    }

    private func submitExtrinsic() {
        guard
            let amountInPlank = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision),
            let collatorId = try? collator.address.toAccountId(),
            let collatorDelegationsCount = collatorMetadata?.delegationCount else {
            return
        }

        let delegationsCount = delegator?.delegations.count ?? 0

        view?.didStartLoading()

        interactor.confirm(
            amountInPlank,
            collator: collatorId,
            collatorDelegationsCount: collatorDelegationsCount,
            delegationsCount: UInt32(delegationsCount),
            existingBond: existingStakeInPlank()
        )
    }

    private func startStaking() {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeAndAmountInPlank(
                balance: balance?.transferable,
                fee: fee,
                spendingAmount: amount,
                precision: precision,
                locale: selectedLocale
            ),
            dataValidatingFactory.canStakeBottomDelegations(
                amount: amount,
                collator: collatorMetadata,
                locale: selectedLocale
            ),
            dataValidatingFactory.hasMinStake(
                amount: amount,
                minTechStake: minTechStake,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }

    private func stakeMore(above _: BigUInt) {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeAndAmountInPlank(
                balance: balance?.transferable,
                fee: fee,
                spendingAmount: amount,
                precision: precision,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}

extension ParaStkStakeConfirmPresenter: ParaStkStakeConfirmPresenterProtocol {
    func setup() {
        provideAmountViewModel()
        provideWalletViewModel()
        provideAccountViewModel()
        provideFeeViewModel()
        provideCollatorViewModel()
        provideHintsViewModel()

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

        refreshFee()
    }

    func didReceiveMinTechStake(_ minStake: BigUInt) {
        minTechStake = minStake
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        self.delegator = delegator

        refreshFee()
    }

    func didReceiveStakingDuration(_ duration: ParachainStakingDuration) {
        stakingDuration = duration

        provideHintsViewModel()
    }

    func didCompleteExtrinsicSubmission(for result: Result<String, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            wireframe.complete(on: view, locale: selectedLocale)
        case let .failure(error):
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)

            logger.error("Extrinsic submission failed: \(error)")
        }
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
