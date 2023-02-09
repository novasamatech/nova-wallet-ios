import Foundation
import SoraFoundation
import BigInt

final class GovernanceDelegateConfirmPresenter {
    weak var view: GovernanceDelegateConfirmViewProtocol?
    let wireframe: GovernanceDelegateConfirmWireframeProtocol
    let interactor: GovernanceDelegateConfirmInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let delegation: GovernanceNewDelegation
    let delegationInfo: GovernanceDelegateFlowDisplayInfo

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol
    let logger: LoggerProtocol

    var assetBalance: AssetBalance?
    var fee: BigUInt?
    var priceData: PriceData?
    var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    var blockTime: BlockTime?
    var referendum: ReferendumLocal?
    var lockDiff: GovernanceDelegateStateDiff?
    var assetLocks: AssetLocks?

    lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceDelegateConfirmInteractorInputProtocol,
        wireframe: GovernanceDelegateConfirmWireframeProtocol,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        delegation: GovernanceNewDelegation,
        delegationInfo: GovernanceDelegateFlowDisplayInfo,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.delegation = delegation
        self.delegationInfo = delegationInfo
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.trackViewModelFactory = trackViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}
