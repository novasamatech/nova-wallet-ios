import Foundation
import Foundation_iOS
import BigInt

final class GovernanceDelegateSetupPresenter {
    weak var view: GovernanceDelegateSetupViewProtocol?
    let wireframe: GovernanceDelegateSetupWireframeProtocol
    let interactor: GovernanceDelegateSetupInteractorInputProtocol

    let selectedAccountId: AccountId
    let chain: ChainModel
    let delegateId: AccountId
    let tracks: [GovernanceTrackInfoLocal]

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let govBalanceCalculator: AvailableBalanceMapping
    let logger: LoggerProtocol

    var assetBalance: AssetBalance?
    var fee: ExtrinsicFeeProtocol?
    var priceData: PriceData?
    var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    var blockTime: BlockTime?
    var lockDiff: GovernanceDelegateStateDiff?

    var inputResult: AmountInputResult?
    var conviction: ConvictionVoting.Conviction = .none

    init(
        interactor: GovernanceDelegateSetupInteractorInputProtocol,
        wireframe: GovernanceDelegateSetupWireframeProtocol,
        selectedAccountId: AccountId,
        chain: ChainModel,
        delegateId: AccountId,
        tracks: [GovernanceTrackInfoLocal],
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        govBalanceCalculator: AvailableBalanceMapping,
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccountId = selectedAccountId
        self.chain = chain
        self.delegateId = delegateId
        self.tracks = tracks
        self.dataValidatingFactory = dataValidatingFactory
        self.govBalanceCalculator = govBalanceCalculator
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    func balanceMinusFee() -> Decimal {
        let balanceValue = govBalanceCalculator.availableBalanceElseZero(from: assetBalance)
        let feeValue = fee?.amountForCurrentAccount ?? 0

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let balance = Decimal.fromSubstrateAmount(balanceValue, precision: precision),
            let fee = Decimal.fromSubstrateAmount(feeValue, precision: precision) else {
            return 0
        }

        return balance - fee
    }

    func deriveNewDelegation() -> GovernanceNewDelegation? {
        let amount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

        guard
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let amountInPlank = amount.toSubstrateAmount(precision: precision) else {
            return nil
        }

        let trackIds = Set(tracks.map(\.trackId))

        return .init(
            delegateId: delegateId,
            trackIds: trackIds,
            balance: amountInPlank,
            conviction: conviction
        )
    }

    func deriveReuseLocks() -> ReferendumReuseLockModel? {
        let governanceLocksInPlank = lockDiff?.before.maxLockedAmount ?? 0
        let allLocksInPlank = assetBalance?.frozenInPlank ?? 0

        guard
            let precision = chain.utilityAssetDisplayInfo()?.assetPrecision,
            let governanceLockDecimal = Decimal.fromSubstrateAmount(governanceLocksInPlank, precision: precision),
            let allLockDecimal = Decimal.fromSubstrateAmount(allLocksInPlank, precision: precision) else {
            return nil
        }

        return ReferendumReuseLockModel(governance: governanceLockDecimal, all: allLockDecimal)
    }

    func refreshFee() {
        guard let newDelegation = deriveNewDelegation(), let voting = votesResult?.value else {
            return
        }

        let actions = newDelegation.createActions(from: voting)

        interactor.estimateFee(for: actions)
    }

    func refreshLockDiff() {
        guard let trackVoting = votesResult?.value, let newDelegation = deriveNewDelegation() else {
            return
        }

        interactor.refreshDelegateStateDiff(for: trackVoting, newDelegation: newDelegation)
    }

    func updateAfterAmountChanged() {
        refreshFee()
        refreshLockDiff()

        updateVotesView()
        updateAmountPriceView()
    }
}
