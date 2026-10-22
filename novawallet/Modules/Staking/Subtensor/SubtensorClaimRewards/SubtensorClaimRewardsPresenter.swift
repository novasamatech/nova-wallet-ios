import Foundation
import Foundation_iOS

final class SubtensorClaimRewardsPresenter {
    weak var view: SubtensorClaimRewardsViewProtocol?
    let wireframe: SubtensorConfirmWireframeProtocol
    let interactor: SubtensorClaimRewardsInteractorInputProtocol

    let chainAsset: ChainAsset
    let model: SubtensorClaimRewardsModel
    let isWatchOnly: Bool
    let viewModelFactory: SubtensorClaimRewardsViewModelFactoryProtocol
    let dataValidationFactory: SubtensorValidationFactoryProtocol
    let logger: LoggerProtocol

    var balance: AssetBalance?
    var price: PriceData?
    var fee: ExtrinsicFeeProtocol?
    var positionsState: Multistaking.SubtensorState?
    var isPositionsSyncFailed = false
    var claimable: [SubtensorRootClaimPreview]?
    var preflight: SubtensorPreflight?
    var existentialDeposit: Balance?
    var pendingClaimHotkeys: Set<AccountId> = []
    var isPriceResolved = false
    var isInitiatedTracked = false
    let dataAnalytics = SubtensorDataAnalytics(screen: .claim)
    private(set) var shownPreview: SubtensorRootClaimPreview
    private(set) var isNothingToClaim = false
    private(set) var isHandingOff = false

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: SubtensorClaimRewardsInteractorInputProtocol,
        wireframe: SubtensorConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        model: SubtensorClaimRewardsModel,
        viewModelFactory: SubtensorClaimRewardsViewModelFactoryProtocol,
        dataValidationFactory: SubtensorValidationFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.model = model
        isWatchOnly = model.account.chainAccount.type == .watchOnly
        self.viewModelFactory = viewModelFactory
        self.dataValidationFactory = dataValidationFactory
        self.logger = logger
        shownPreview = model.shownPreview

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
            validatorName: model.validator.name,
            rootStake: isPositionsSyncFailed || positionsState == nil ? nil : rootGroup?.totalAlpha ?? 0,
            unlockTime: preflight.map { TimeInterval($0.rootStakeUnlockInterval) * $0.blockTime.timeInterval },
            otherClaimableCount: claimable.map {
                SubtensorRootClaimRule.otherClaimableCount(in: $0, target: hotkey)
            } ?? 0,
            price: price,
            fee: fee,
            isWatchOnly: isWatchOnly,
            isNothingToClaim: isNothingToClaim
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }

    func refreshFee() {
        interactor.estimateFee(for: .rootClaim(hotkey: hotkey))
    }

    func refreshPreflight() {
        interactor.refreshPreflight(for: hotkey, netuid: SubtensorPallet.rootNetuid)
    }

    func applySilently(_ claimable: [SubtensorRootClaimPreview]) {
        guard
            let preview = claimable.first(where: { $0.hotkey == hotkey }),
            SubtensorRootClaimRule.isClaimable(preview) else {
            return
        }

        shownPreview = preview
    }

    func finishHandOff() {
        isHandingOff = false
        view?.didStopLoading()
    }
}

private extension SubtensorClaimRewardsPresenter {
    var rootGroup: SubtensorPortfolioGroup? {
        positionsState.flatMap { SubtensorPortfolioBuilder.build(state: $0).root }
    }

    func presentNothingToClaim() {
        guard let view else {
            return
        }

        wireframe.presentNothingToClaim(view, locale: selectedLocale)
    }

    func presentAmountChanged() {
        guard let view else {
            return
        }

        wireframe.presentClaimAmountChanged(view, locale: selectedLocale)
    }

    func createValidations() -> [DataValidating] {
        let locale = selectedLocale
        let isPending = pendingClaimHotkeys.contains(hotkey)
        let reporter = createValidationReporter()

        var validations: [DataValidating] = [
            dataValidationFactory.positionsAreFresh(
                syncFailed: isPositionsSyncFailed || positionsState?.isRootRedeemableStale == true,
                locale: locale,
                onRetry: { [weak self] in
                    self?.interactor.refreshPositions()
                }
            ).reporting(.staleData, to: reporter),
            dataValidationFactory.has(fee: fee, locale: locale, onError: { [weak self] in
                self?.refreshFee()
            }).reporting(.feeInProgress, to: reporter),
            dataValidationFactory.hasPreflight(preflight, locale: locale, onRetry: { [weak self] in
                self?.refreshPreflight()
            })
        ]

        validations.append(
            contentsOf: dataValidationFactory.createNetworkStateValidations(for: preflight, locale: locale)
        )

        validations.append(ErrorConditionViolation(onError: { [weak self, weak view, wireframe] in
            self?.trackBlocked(.claimPending)

            guard let view else {
                return
            }

            wireframe.presentClaimPending(view, locale: locale)
        }, preservesCondition: {
            !isPending
        }))

        validations.append(
            contentsOf: [
                dataValidationFactory.canPayFeeInPlank(
                    balance: balance?.transferable,
                    fee: fee,
                    asset: chainAsset.assetDisplayInfo,
                    locale: locale
                ).reporting(.insufficientBalance, to: reporter),
                dataValidationFactory.notViolatingMinBalancePaying(
                    fee: fee,
                    total: balance?.transferable,
                    minBalance: existentialDeposit,
                    asset: chainAsset.assetDisplayInfo,
                    locale: locale
                ).reporting(.insufficientBalance, to: reporter)
            ]
        )

        return validations
    }

    func verifyAtTap() {
        guard let claimable else {
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.confirm()
            }
            return
        }

        switch SubtensorClaimTapRule.verdict(shown: shownPreview, fresh: claimable) {
        case .nothingToClaim:
            isNothingToClaim = true
            trackBlocked(.claimBelowMinimum)
            provideViewModel()
            presentNothingToClaim()
        case let .changed(preview):
            shownPreview = preview
            provideViewModel()
            presentAmountChanged()
        case let .proceed(preview):
            shownPreview = preview
            provideViewModel()
            handOffAfterProfitCheck(with: preview)
        }
    }

    func handOffAfterProfitCheck(with preview: SubtensorRootClaimPreview) {
        let validation = dataValidationFactory.hasProfitAfterClaim(
            rewards: preview.redeemable,
            fee: fee,
            locale: selectedLocale
        )

        DataValidationRunner(validators: [validation]).runValidation { [weak self] in
            self?.handOff(with: preview)
        }
    }

    func handOff(with preview: SubtensorRootClaimPreview) {
        guard !isHandingOff, let fee, let preflight else {
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
            costBasis: nil,
            blockTime: preflight.blockTime
        )

        isHandingOff = true
        view?.didStartLoading()

        wireframe.showOperationResult(from: view, request: request, delegate: self)
    }
}

extension SubtensorClaimRewardsPresenter: SubtensorClaimRewardsPresenterProtocol {
    func setup() {
        trackWatchOnlyIfNeeded()
        provideAccountViewModels()
        provideViewModel()

        interactor.setup()
        interactor.loadExistentialDeposit()

        refreshPreflight()
        refreshFee()
    }

    func confirm() {
        guard !isWatchOnly, !isNothingToClaim, !isHandingOff else {
            return
        }

        interactor.refreshPendingClaims(for: claimable)

        DataValidationRunner(validators: createValidations()).runValidation { [weak self] in
            self?.verifyAtTap()
        }
    }

    func selectAccount() {
        guard let view, let address = model.account.chainAccount.toAddress() else {
            return
        }

        wireframe.presentAccountOptions(from: view, address: address, chain: chainAsset.chain, locale: selectedLocale)
    }

    func selectValidator() {
        wireframe.showValidatorInfo(from: view, target: .root, hotkey: hotkey, detail: nil)
    }
}
