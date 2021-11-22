final class AnyValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let validatorInfo: ValidatorInfoProtocol

    init(
        selectedAsset: AssetModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        validatorInfo: ValidatorInfoProtocol
    ) {
        self.validatorInfo = validatorInfo
        super.init(selectedAsset: selectedAsset, priceLocalSubscriptionFactory: priceLocalSubscriptionFactory)
    }

    override func setup() {
        super.setup()
        presenter?.didReceiveValidatorInfo(result: .success(validatorInfo))
    }

    override func reload() {
        super.reload()
        presenter?.didReceiveValidatorInfo(result: .success(validatorInfo))
    }
}
