import Foundation
import SoraFoundation

final class MythosStkUnstakeSetupPresenter {
    weak var view: MythosStkUnstakeSetupViewProtocol?
    let wireframe: MythosStkUnstakeSetupWireframeProtocol
    let interactor: MythosStkUnstakeSetupInteractorInputProtocol

    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: MythosStakingValidationFactoryProtocol
    let accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol
    let hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol

    private(set) var fee: ExtrinsicFeeProtocol?
    private(set) var balance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var collatorDisplayAddress: DisplayAddress?
    private(set) var stakingDetails: MythosStakingDetails?
    private(set) var delegationIdentities: [AccountId: AccountIdentity]?
    private(set) var claimableRewards: MythosStakingClaimableRewards?
    private(set) var stakingDuration: MythosStakingDuration?

    let logger: LoggerProtocol

    init(
        interactor: MythosStkUnstakeSetupInteractorInputProtocol,
        wireframe: MythosStkUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: MythosStakingValidationFactoryProtocol,
        accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol,
        hintViewModelFactory: CollatorStakingHintsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.accountDetailsViewModelFactory = accountDetailsViewModelFactory
        self.hintViewModelFactory = hintViewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

extension MythosStkUnstakeSetupPresenter: MythosStkUnstakeSetupPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension MythosStkUnstakeSetupPresenter: MythosStkUnstakeSetupInteractorOutputProtocol {
    func didReceiveDelegationIdentities(_: [AccountId: AccountIdentity]?) {}

    func didReceiveBalance(_: AssetBalance?) {}

    func didReceivePrice(_: PriceData?) {}

    func didReceiveStakingDetails(_: MythosStakingDetails?) {}

    func didReceiveClaimableRewards(_: MythosStakingClaimableRewards?) {}

    func didReceiveStakingDuration(_: MythosStakingDuration) {}

    func didReceiveFee(_: ExtrinsicFeeProtocol) {}

    func didReceiveBaseError(_: MythosStkUnstakeInteractorError) {}
}

extension MythosStkUnstakeSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            // TODO: Add logic here
        }
    }
}
