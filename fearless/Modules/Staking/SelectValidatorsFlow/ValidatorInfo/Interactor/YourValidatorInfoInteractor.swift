import RobinHood
import IrohaCrypto

final class YourValidatorInfoInteractor: ValidatorInfoInteractorBase {
    private let accountAddress: AccountAddress
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol

    init(
        accountAddress: AccountAddress,
        selectedAsset: AssetModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.accountAddress = accountAddress
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager

        super.init(selectedAsset: selectedAsset, priceLocalSubscriptionFactory: priceLocalSubscriptionFactory)
    }

    private func fetchValidatorInfo() {
        do {
            let accountId = try accountAddress.toAccountId()

            presenter.didStartLoadingValidatorInfo()

            let operation = validatorOperationFactory.wannabeValidatorsOperation(for: [accountId])

            operation.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        if let validatorInfo =
                            try operation.targetOperation.extractNoCancellableResultData().first {
                            self?.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                        } else {
                            let validatorInfo = SelectedValidatorInfo(address: self?.accountAddress ?? "")
                            self?.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                        }
                    } catch {
                        self?.presenter.didReceiveValidatorInfo(result: .failure(error))
                    }
                }
            }

            operationManager.enqueue(operations: operation.allOperations, in: .transient)
        } catch {
            presenter.didReceiveValidatorInfo(result: .failure(error))
        }
    }

    override func setup() {
        super.setup()

        fetchValidatorInfo()
    }

    override func reload() {
        super.reload()
        fetchValidatorInfo()
    }
}
