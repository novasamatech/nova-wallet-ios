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

    func canPayFee(
        params: MultisigBalanceValidationParams,
        locale: Locale
    ) -> DataValidating

    func canPayDeposit(
        params: MultisigBalanceValidationParams,
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
        case let .delegatedSigner(rootSignerParams, delegatedSignerParams):
            [
                canPayDeposit(
                    params: delegatedSignerParams,
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
            let depositDecimal = params.deposit?.decimal(assetInfo: params.asset)
            let feeDecimal = params.fee?.amountForCurrentAccount?.decimal(assetInfo: params.asset)

            let balanceModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: balanceDecimal
            ).value(for: locale)

            let depositModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: depositDecimal ?? 0
            ).value(for: locale)

            let feeModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: feeDecimal ?? 0
            ).value(for: locale)

            self?.presentable.presentNotEnoughBalanceForDeposit(
                from: view,
                deposit: depositModel,
                balance: balanceModel,
                accountName: params.metaAccountResponse.chainAccount.name,
                locale: locale
            )
        }, preservesCondition: {
            guard
                let deposit = params.deposit,
                let fee = params.fee?.amountForCurrentAccount
            else { return false }

            return params.available >= deposit + fee
        })
    }

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
            let depositDecimal = params.deposit?.decimal(assetInfo: params.asset)

            let balanceModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: balanceDecimal
            ).value(for: locale)

            let depositModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: depositDecimal ?? 0
            ).value(for: locale)

            self?.presentable.presentNotEnoughBalanceForDeposit(
                from: view,
                deposit: depositModel,
                balance: balanceModel,
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

            let balanceString = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: balanceDecimal
            ).value(for: locale)

            let feeDecimal = params.fee?.amountForCurrentAccount?.decimal(assetInfo: params.asset)

            let feeString = viewModelFactory.amountFromValue(
                targetAssetInfo: params.asset,
                value: feeDecimal ?? 0
            ).value(for: locale)

            self?.presentable.presentFeeTooHigh(
                from: view,
                balance: balanceString,
                fee: feeString,
                accountName: params.metaAccountResponse.chainAccount.name,
                locale: locale
            )

        }, preservesCondition: {
            guard let fee = params.fee else { return false }

            guard let feeAmountInPlank = fee.amountForCurrentAccount else { return true }

            return feeAmountInPlank <= params.available
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
