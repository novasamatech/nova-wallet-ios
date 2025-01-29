import Foundation
import SoraFoundation

final class MythosStkUnstakeConfirmPresenter {
    weak var view: MythosStkUnstakeConfirmViewProtocol?
    let wireframe: MythosStkUnstakeConfirmWireframeProtocol
    let interactor: MythosStkUnstakeConfirmInteractorInputProtocol

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let selectedCollator: DisplayAddress
    let dataValidatingFactory: MythosStakingValidationFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol
    let logger: LoggerProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var stakingDetails: MythosStakingDetails?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var claimableRewards: MythosStakingClaimableRewards?
    private(set) var stakingDuration: MythosStakingDuration?

    private lazy var walletViewModelFactory = WalletAccountViewModelFactory()
    private lazy var displayAddressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        interactor: MythosStkUnstakeConfirmInteractorInputProtocol,
        wireframe: MythosStkUnstakeConfirmWireframeProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        selectedCollator: DisplayAddress,
        dataValidatingFactory: MythosStakingValidationFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.selectedCollator = selectedCollator
        self.dataValidatingFactory = dataValidatingFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.hintViewModelFactory = hintViewModelFactory
        self.logger = logger

        self.localizationManager = localizationManager
    }
}

extension MythosStkUnstakeConfirmPresenter: MythosStkUnstakeConfirmPresenterProtocol {
    func setup() {}
}

extension MythosStkUnstakeConfirmPresenter: MythosStkUnstakeConfirmInteractorOutputProtocol {
    func didReceiveBalance(_ assetBalance: AssetBalance?) {
        
    }
    
    func didReceivePrice(_ price: PriceData?) {
        
    }
    
    func didReceiveStakingDetails(_ details: MythosStakingDetails?) {
        
    }
    
    func didReceiveClaimableRewards(_ rewards: MythosStakingClaimableRewards?) {
        
    }
    
    func didReceiveStakingDuration(_ duration: MythosStakingDuration) {
        
    }
    
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        
    }
    
    func didReceiveBaseError(_ error: MythosStkUnstakeInteractorError) {
        
    }
    
    func didReceiveSubmissionResult(_ result: Result<ExtrinsicHash, Error>) {
        view?.didStopLoading()

        switch result {
        case .success:
            wireframe.presentExtrinsicSubmission(
                from: view,
                completionAction: .dismiss,
                locale: selectedLocale
            )
        case let .failure(error):
            wireframe.handleExtrinsicSigningErrorPresentationElseDefault(
                error,
                view: view,
                closeAction: .dismiss,
                locale: selectedLocale,
                completionClosure: nil
            )
        }
    }
}

extension MythosStkUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            // TODO: Update implementation
        }
    }
}
