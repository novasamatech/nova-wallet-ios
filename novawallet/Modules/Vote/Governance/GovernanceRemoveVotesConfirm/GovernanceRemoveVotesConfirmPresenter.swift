import Foundation
import BigInt

final class GovernanceRemoveVotesConfirmPresenter {
    weak var view: GovernanceRemoveVotesConfirmViewProtocol?
    let wireframe: GovernanceRemoveVotesConfirmWireframeProtocol
    let interactor: GovernanceRemoveVotesConfirmInteractorInputProtocol

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: GovernanceValidatorFactoryProtocol
    let logger: LoggerProtocol

    private var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>
    private var assetBalance: AssetBalance?
    private var price: PriceData?
    private var fee: BigUInt?

    private lazy var walletDisplayViewModelFactory = WalletAccountViewModelFactory()
    private lazy var addressDisplayViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: GovernanceRemoveVotesConfirmInteractorInputProtocol,
        wireframe: GovernanceRemoveVotesConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension GovernanceRemoveVotesConfirmPresenter: GovernanceRemoveVotesConfirmPresenterProtocol {
    func setup() {}
}

extension GovernanceRemoveVotesConfirmPresenter: GovernanceRemoveVotesConfirmInteractorOutputProtocol {
    func didReceiveVotingResult(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        
    }

    func didReceiveBalance(_ assetBalance: AssetBalance?) {

    }

    func didReceiveRemoveVotesHash(_ hash: String) {

    }

    func didReceiveFee(_ fee: BigUInt) {

    }

    func didReceiveError(_ error: GovernanceRemoveVotesInteractorError) {

    }
}
