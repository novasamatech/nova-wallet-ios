import Foundation
import BigInt
import Foundation_iOS

protocol MultisigDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasSufficientBalance(
        params: MultisigBalanceValidationModeParams,
        locale: Locale
    ) -> [DataValidating]

    func operationNotExists(
        callHash: Substrate.CallHash,
        callHashSet: Set<Substrate.CallHash>?,
        accountName: String,
        locale: Locale
    ) -> DataValidating
}

final class MultisigDataValidatorFactory {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }
    let presentable: MultisigErrorPresentable
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(
        presentable: MultisigErrorPresentable,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.presentable = presentable
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }
}

// MARK: - Private

private extension MultisigDataValidatorFactory {
    func canPayDeposit(
        params: MultisigBalanceValidationParams,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard
                let view = self?.view,
                let viewModelFactory = self?.balanceViewModelFactoryFacade
            else { return }

            let balanceDecimal = params.available.decimal(assetInfo: params.asset)
            let depositDecimal = params.deposit?.decimal(assetInfo: params.asset) ?? 0

            let remainingDecimal = depositDecimal - balanceDecimal

            let remainingModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: remainingDecimal
            ).value(for: locale)

            let depositModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: depositDecimal
            ).value(for: locale)

            self?.presentable.presentNotEnoughBalanceForDeposit(
                from: view,
                deposit: depositModel,
                remaining: remainingModel,
                accountName: params.metaAccountResponse.chainAccount.name,
                locale: locale
            )
        }, preservesCondition: {
            guard let deposit = params.deposit else { return false }

            return params.available >= deposit
        })
    }

    func canPayFee(
        params: MultisigBalanceValidationParams,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view, let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                return
            }

            let balanceDecimal = params.available.decimal(assetInfo: params.asset)
            let feeDecimal = params.fee?.amountForCurrentAccount?.decimal(assetInfo: params.asset) ?? 0

            let remainingDecimal = feeDecimal - balanceDecimal

            let remainingModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: remainingDecimal
            ).value(for: locale)

            let feeModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: feeDecimal
            ).value(for: locale)

            self?.presentable.presentNotEnoughBalanceForFee(
                from: view,
                fee: feeModel,
                remaining: remainingModel,
                accountName: params.metaAccountResponse.chainAccount.name,
                locale: locale
            )

        }, preservesCondition: {
            guard let fee = params.fee else { return false }

            guard let feeAmountInPlank = fee.amountForCurrentAccount else { return true }

            return feeAmountInPlank <= params.available
        })
    }
}

// MARK: - MultisigDataValidatorFactoryProtocol

extension MultisigDataValidatorFactory: MultisigDataValidatorFactoryProtocol {
    func hasSufficientBalance(
        params: MultisigBalanceValidationModeParams,
        locale: Locale
    ) -> [DataValidating] {
        switch params {
        case let .rootSigner(signerParams):
            [
                hasSufficientBalance(
                    params: signerParams,
                    locale: locale
                )
            ]
        case let .delegatedSigner(rootSignerParams, signatoryParams):
            [
                canPayDeposit(
                    params: signatoryParams,
                    locale: locale
                ),
                canPayFee(
                    params: rootSignerParams,
                    locale: locale
                )
            ]
        }
    }

    func hasSufficientBalance(
        params: MultisigBalanceValidationParams,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard
                let view = self?.view,
                let viewModelFactory = self?.balanceViewModelFactoryFacade
            else { return }

            let balanceDecimal = params.available.decimal(assetInfo: params.asset)
            let depositDecimal = params.deposit?.decimal(assetInfo: params.asset) ?? 0
            let feeDecimal = params.fee?.amountForCurrentAccount?.decimal(assetInfo: params.asset) ?? 0

            let remainingDecimal = (depositDecimal + feeDecimal) - balanceDecimal

            let remainingModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: remainingDecimal
            ).value(for: locale)

            let depositModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: depositDecimal
            ).value(for: locale)

            let feeModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: feeDecimal
            ).value(for: locale)

            self?.presentable.presentNotEnoughBalanceForDepositAndFee(
                from: view,
                deposit: depositModel,
                fee: feeModel,
                remaining: remainingModel,
                accountName: params.metaAccountResponse.chainAccount.name,
                locale: locale
            )
        }, preservesCondition: {
            guard
                let deposit = params.deposit,
                let fee = params.fee
            else { return false }

            guard let feeAmountInPlank = fee.amountForCurrentAccount else { return true }

            return params.available >= deposit + feeAmountInPlank
        })
    }

    func operationNotExists(
        callHash: Substrate.CallHash,
        callHashSet: Set<Substrate.CallHash>?,
        accountName: String,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentOperationAlreadyAdded(
                from: view,
                accountName: accountName,
                locale: locale
            )
        }, preservesCondition: {
            guard let callHashSet else {
                return false
            }

            return !callHashSet.contains(callHash)
        })
    }
}
