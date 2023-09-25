import Foundation
import SoraFoundation

final class StartStakingDirectConfirmPresenter: StartStakingConfirmPresenter {
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let model: PreparedValidators

    var directWireframe: StartStakingDirectConfirmWireframeProtocol? {
        wireframe as? StartStakingDirectConfirmWireframeProtocol
    }

    init(
        model: PreparedValidators,
        interactor: StartStakingConfirmInteractorInputProtocol,
        wireframe: StartStakingDirectConfirmWireframeProtocol,
        amount: Decimal,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.model = model
        self.quantityFormatter = quantityFormatter

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
        let stakingType = R.string.localizable.stakingTypeDirect(
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.didReceiveStakingType(viewModel: stakingType)
    }

    override func provideStakingDetails() {
        let title = R.string.localizable.stakingRecommendedTitle(preferredLanguages: selectedLocale.rLanguages)

        let selectedString = quantityFormatter.value(
            for: selectedLocale
        ).string(from: .init(value: model.targets.count)) ?? ""

        let maxString = quantityFormatter.value(
            for: selectedLocale
        ).string(from: .init(value: model.targets.count)) ?? ""

        let details = R.string.localizable.stakingValidatorInfoNominators(
            selectedString,
            maxString,
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.didReceiveStakingDetails(
            title: title,
            info: .init(address: "", name: details, imageViewModel: nil)
        )
    }

    override func showStakingDetails() {
        directWireframe?.showSelectedValidators(from: view, validators: model)
    }

    override func createStakingSpecificValidations() -> [DataValidating] {
        [
            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: assetBalance?.freeInPlank,
                fee: fee,
                spendingAmount: amount,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            )
        ]
    }

    override func stakingOption() -> SelectedStakingOption? {
        .direct(model)
    }
}
