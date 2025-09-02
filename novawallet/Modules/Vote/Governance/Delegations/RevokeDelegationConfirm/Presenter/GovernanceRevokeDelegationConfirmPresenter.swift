import Foundation
import BigInt
import Foundation_iOS

final class GovRevokeDelegationConfirmPresenter {
    weak var view: GovernanceRevokeDelegationConfirmViewProtocol?
    let wireframe: GovernanceRevokeDelegationConfirmWireframeProtocol
    let interactor: GovernanceRevokeDelegationConfirmInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let selectedTracks: [GovernanceTrackInfoLocal]
    let delegationInfo: GovernanceDelegateFlowDisplayInfo<AccountId>

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let trackViewModelFactory: GovernanceTrackViewModelFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let logger: LoggerProtocol

    var assetBalance: AssetBalance?
    var fee: ExtrinsicFeeProtocol?
    var priceData: PriceData?
    var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    var blockTime: BlockTime?
    var referendum: ReferendumLocal?
    var lockDiff: GovernanceDelegateStateDiff?
    var assetLocks: AssetLocks?

    lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceRevokeDelegationConfirmInteractorInputProtocol,
        wireframe: GovernanceRevokeDelegationConfirmWireframeProtocol,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        selectedTracks: [GovernanceTrackInfoLocal],
        delegationInfo: GovernanceDelegateFlowDisplayInfo<AccountId>,
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
        self.selectedTracks = selectedTracks
        self.delegationInfo = delegationInfo
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.trackViewModelFactory = trackViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}
