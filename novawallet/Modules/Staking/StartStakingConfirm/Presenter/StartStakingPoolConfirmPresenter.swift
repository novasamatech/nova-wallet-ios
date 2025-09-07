import Foundation
import Foundation_iOS

final class StartStakingPoolConfirmPresenter: StartStakingConfirmPresenter {
    let model: NominationPools.SelectedPool

    private lazy var addressViewModelFactory = DisplayAddressViewModelFactory()

    init(
        model: NominationPools.SelectedPool,
        interactor: StartStakingConfirmInteractorInputProtocol,
        wireframe: StartStakingConfirmWireframeProtocol,
        amount: Decimal,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.model = model

        super.init(
            interactor: interactor,
            wireframe: wireframe,
            amount: amount,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    override func provideStakingType() {
        let stakingType = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingTypeNominationPool()

        view?.didReceiveStakingType(viewModel: stakingType)
    }

    override func provideStakingDetails() {
        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.stakingPool()

        let viewModel = addressViewModelFactory.createViewModel(from: model, chainAsset: chainAsset)

        view?.didReceiveStakingDetails(title: title, info: viewModel)
    }

    override func showStakingDetails() {
        if let address = model.bondedAddress(for: chainAsset.chain.chainFormat) {
            showDetails(for: address)
        }
    }

    override func createStakingSpecificValidations() -> [DataValidating] {
        [
            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: assetBalance?.transferable,
                fee: fee,
                spendingAmount: amount,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]
    }

    override func stakingOption() -> SelectedStakingOption? {
        .pool(model)
    }
}
