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

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol
    let lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let logger: LoggerProtocol

    private var assetBalance: AssetBalance?
    private var fee: BigUInt?
    private var priceData: PriceData?
    private var votesResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var referendum: ReferendumLocal?
    private var lockDiff: GovernanceLockStateDiff?
    private var assetLocks: AssetLocks?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceDelegateConfirmInteractorInputProtocol,
        wireframe: GovernanceDelegateConfirmWireframeProtocol,
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        delegation: GovernanceNewDelegation,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        referendumStringsViewModelFactory: ReferendumDisplayStringFactoryProtocol,
        lockChangeViewModelFactory: ReferendumLockChangeViewModelFactoryProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.delegation = delegation
        self.balanceViewModelFactory = balanceViewModelFactory
        self.referendumStringsViewModelFactory = referendumStringsViewModelFactory
        self.lockChangeViewModelFactory = lockChangeViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension GovernanceDelegateConfirmPresenter: GovernanceDelegateConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func presentSenderAccount() {

    }

    func presentDelegateAccount() {

    }

    func presentTracks() {

    }

    func confirm() {

    }
}

extension GovernanceDelegateConfirmPresenter: GovernanceDelegateConfirmInteractorOutputProtocol {
    func didReceiveLocks(_ locks: AssetLocks) {

    }

    func didReceiveSubmissionHash(_ hash: String) {

    }

    func didReceiveError(_ error: GovernanceDelegateConfirmInteractorError) {

    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {

    }

    func didReceivePrice(_ price: PriceData?) {

    }

    func didReceiveFee(_ fee: BigUInt) {

    }

    func didReceiveDelegateStateDiff(_ stateDiff: GovernanceDelegateStateDiff) {

    }

    func didReceiveAccountVotes(_ votes: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {

    }

    func didReceiveBlockNumber(_ number: BlockNumber) {

    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {

    }

    func didReceiveBaseError(_ error: GovernanceDelegateInteractorError) {

    }
}

extension GovernanceDelegateConfirmPresenter: Localizable {
    func applyLocalization() {

    }
}
