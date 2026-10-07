import Foundation
import Foundation_iOS

final class SubtensorClaimRewardsPresenter {
    weak var view: SubtensorClaimRewardsViewProtocol?
    let wireframe: SubtensorClaimRewardsWireframeProtocol
    let interactor: SubtensorClaimInteractorInputProtocol

    let chainAsset: ChainAsset
    let model: SubtensorClaimRewardsModel
    let signing: SubtensorOperationGate.Verdict
    let pendingRootClaims: SubtensorPendingRootClaimsProtocol
    let viewModelFactory: SubtensorClaimViewModelFactoryProtocol
    let dataValidationFactory: SubtensorStakingValidationFactoryProtocol
    let logger: LoggerProtocol

    var balance: AssetBalance?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var positionsState: Multistaking.SubtensorStakingState?
    var isPositionsSyncFailed = false
    var claimable: SubtensorRootClaimable?
    var preflight: SubtensorStakingPreflight?
    var existentialDeposit: Balance?
    private(set) var shownPreview: SubtensorRootClaimPreview
    private(set) var minimumClaim: Balance
    private(set) var isNothingToClaim = false
    private(set) var isVerifyingAtTap = false
    private(set) var isHandingOff = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorClaimInteractorInputProtocol,
        wireframe: SubtensorClaimRewardsWireframeProtocol,
        chainAsset: ChainAsset,
        model: SubtensorClaimRewardsModel,
        pendingRootClaims: SubtensorPendingRootClaimsProtocol,
        viewModelFactory: SubtensorClaimViewModelFactoryProtocol,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.model = model
        signing = SubtensorOperationGate.verdict(for: model.account.chainAccount.type)
        self.pendingRootClaims = pendingRootClaims
        self.viewModelFactory = viewModelFactory
        self.dataValidationFactory = dataValidationFactory
        self.logger = logger
        shownPreview = model.shownPreview
        minimumClaim = model.minimumClaim

        self.localizationManager = localizationManager
    }
}

extension SubtensorClaimRewardsPresenter {
    var hotkey: AccountId {
        model.validator.hotkey
    }

    func provideAccountViewModels() {
        do {
            let walletViewModel = try walletViewModelFactory.createDisplayViewModel(from: model.account)
            view?.didReceiveWallet(viewModel: walletViewModel)

            let accountViewModel = try walletViewModelFactory.createViewModel(from: model.account)
            view?.didReceiveAccount(viewModel: accountViewModel.rawDisplayAddress())
        } catch {
            logger.error("Wallet view model failed: \(error)")
        }

        let validatorViewModel = displayAddressViewModelFactory.createViewModel(from: model.validator.display)
        view?.didReceiveValidator(viewModel: validatorViewModel)
    }

    func provideViewModel() {
        let input = SubtensorClaimRewardsViewModelInput(
            preview: shownPreview,
            validatorName: validatorName,
            rootStake: isPositionsSyncFailed || positionsState == nil ? nil : rootGroup?.totalAlpha ?? 0,
            unlockInterval: preflight?.rootStakeUnlockInterval,
            otherClaimableCount: claimable.map {
                SubtensorRootClaimRule.otherClaimableCount(in: $0, target: hotkey)
            } ?? 0,
            price: price,
            fee: fee,
            signing: signing,
            isNothingToClaim: isNothingToClaim
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }

    func refreshFee() {
        interactor.estimateFee(for: .rootClaim(hotkey: hotkey))
    }

    func refreshPreflight() {
        interactor.refreshPreflight(for: hotkey, netuid: SubtensorStakingPallet.rootNetuid)
    }

    func handleClaimSnapshot(_ claimable: SubtensorRootClaimable) {
        self.claimable = claimable

        guard isVerifyingAtTap else {
            applySilently(claimable)
            provideViewModel()
            return
        }

        isVerifyingAtTap = false

        switch SubtensorClaimTapRule.verdict(shown: shownPreview, fresh: claimable) {
        case .nothingToClaim:
            isNothingToClaim = true
            view?.didStopLoading()
            provideViewModel()
            presentNothingToClaim(minimum: claimable.minimumClaim ?? minimumClaim)
        case let .changed(preview):
            accept(preview, from: claimable)
            view?.didStopLoading()
            provideViewModel()
            presentAmountChanged()
        case let .proceed(preview):
            accept(preview, from: claimable)
            provideViewModel()
            handOff(with: preview)
        }
    }

    func handleClaimSnapshotFailure() {
        guard isVerifyingAtTap else {
            return
        }

        isVerifyingAtTap = false
        view?.didStopLoading()

        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.confirm()
        }
    }

    func finishHandOff() {
        isHandingOff = false
        view?.didStopLoading()
    }
}

private extension SubtensorClaimRewardsPresenter {
    var validatorName: String {
        let display = model.validator.display

        return display.username.isEmpty ? display.address.truncated : display.username
    }

    var rootGroup: SubtensorPortfolioGroup? {
        positionsState.flatMap { SubtensorPortfolioBuilder.build(state: $0).root }
    }

    func applySilently(_ claimable: SubtensorRootClaimable) {
        guard
            let minimumClaim = claimable.minimumClaim,
            let preview = claimable.previews.first(where: { $0.hotkey == hotkey }),
            SubtensorRootClaimRule.isClaimable(preview, minimumClaim: minimumClaim) else {
            return
        }

        accept(preview, from: claimable)
    }

    func accept(_ preview: SubtensorRootClaimPreview, from claimable: SubtensorRootClaimable) {
        shownPreview = preview
        minimumClaim = claimable.minimumClaim ?? minimumClaim
    }

    func presentNothingToClaim(minimum: Balance) {
        guard let view else {
            return
        }

        wireframe.presentNothingToClaim(
            view,
            minimum: viewModelFactory.createMinimumClaim(minimum, locale: selectedLocale),
            locale: selectedLocale
        )
    }

    func presentAmountChanged() {
        guard let view else {
            return
        }

        wireframe.presentClaimAmountChanged(view, locale: selectedLocale)
    }

    func createValidations() -> [DataValidating] {
        let locale = selectedLocale

        let isPending = pendingRootClaims.pendingHotkeys(
            for: model.account.chainAccount.accountId,
            at: Date(),
            claimable: claimable
        ).contains(hotkey)

        let feePayingBalance = existentialDeposit.flatMap { deposit in
            balance.map { $0.transferable.subtractOrZero(deposit) }
        }

        var validations: [DataValidating] = [
            dataValidationFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFee()
            }),
            dataValidationFactory.hasPreflight(preflight, locale: locale, onRetry: { [weak self] in
                self?.refreshPreflight()
            })
        ]

        validations.append(
            contentsOf: SubtensorCommonValidations.createNetworkStateValidations(
                for: preflight,
                dataValidationFactory: dataValidationFactory,
                locale: locale
            )
        )

        validations.append(
            SubtensorClaimValidations.claimNotPending(
                isPending: isPending,
                wireframe: wireframe,
                view: view,
                locale: locale
            )
        )

        validations.append(
            dataValidationFactory.canPayFeeInPlank(
                balance: feePayingBalance,
                fee: fee,
                asset: chainAsset.assetDisplayInfo,
                locale: locale
            )
        )

        return validations
    }

    func verifyAtTap() {
        guard !isVerifyingAtTap, !isHandingOff else {
            return
        }

        isVerifyingAtTap = true
        view?.didStartLoading()

        interactor.refreshClaimSnapshot()
    }

    func handOff(with preview: SubtensorRootClaimPreview) {
        guard !isHandingOff, let fee else {
            view?.didStopLoading()
            return
        }

        let group = rootGroup
        let hotkeysAfterClaim = Set(group?.positions.map(\.hotkey) ?? []).union([preview.hotkey])

        let request = SubtensorOperationResultRequest(
            operation: .rootClaim(hotkey: preview.hotkey),
            origin: .claim,
            account: model.account,
            target: .root,
            payAmount: preview.redeemable,
            quote: nil,
            slippage: nil,
            validator: model.validator,
            estimatedNetworkFee: fee,
            stakeBefore: group?.totalAlpha ?? 0,
            groupHotkeyCount: hotkeysAfterClaim.count,
            emptiesPosition: false,
            prices: SubtensorOperationResultPrices(taoPrice: price, alphaSpot: nil),
            costBasis: nil
        )

        isHandingOff = true

        wireframe.showOperationResult(from: view, request: request, delegate: self)
    }
}

extension SubtensorClaimRewardsPresenter: SubtensorClaimRewardsPresenterProtocol {
    func setup() {
        provideAccountViewModels()
        provideViewModel()

        interactor.setup()

        refreshPreflight()
        refreshFee()
        interactor.refreshClaimSnapshot()
    }

    func confirm() {
        guard signing == .allowed, !isNothingToClaim, !isVerifyingAtTap, !isHandingOff else {
            return
        }

        DataValidationRunner(validators: createValidations()).runValidation { [weak self] in
            self?.verifyAtTap()
        }
    }

    func selectAccount() {
        guard let address = model.account.chainAccount.toAddress() else {
            return
        }

        wireframe.showSubtensorInfo(.account(address: address, chain: chainAsset.chain), from: view)
    }

    func selectValidator() {
        wireframe.showValidatorInfo(from: view, target: .root, hotkey: hotkey, detail: nil)
    }
}
