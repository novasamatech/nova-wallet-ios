import Foundation
import BigInt
import Foundation_iOS

struct MultisigDepositValidationParams {
    let deposit: Balance?
    let balance: Balance?
    let payedFee: Balance?
    let signatoryName: String
    let assetInfo: AssetBalanceDisplayInfo
}

struct MultisigFeeValidationParams {
    let balance: Balance?
    let fee: ExtrinsicFeeProtocol?
    let signatoryName: String
    let assetInfo: AssetBalanceDisplayInfo
}

protocol MultisigDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func canReserveDeposit(
        params: MultisigDepositValidationParams,
        locale: Locale
    ) -> DataValidating

    func canPayFee(
        params: MultisigFeeValidationParams,
        locale: Locale
    ) -> DataValidating

    func operationNotExists(
        _ noOperation: Bool,
        multisigName: String,
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
    func canReserveDeposit(
        params: MultisigDepositValidationParams,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard
                let view = self?.view,
                let viewModelFactory = self?.balanceViewModelFactoryFacade
            else { return }

            let balanceDecimal = params.balance?.decimal(assetInfo: params.assetInfo) ?? 0
            let depositDecimal = params.deposit?.decimal(assetInfo: params.assetInfo) ?? 0

            let needToAdd = depositDecimal - balanceDecimal

            let needToAddModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.assetInfo,
                value: needToAdd
            ).value(for: locale)

            let depositModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.assetInfo,
                value: depositDecimal
            ).value(for: locale)

            let feeModel = params.payedFee.map { actualFee in
                let feeDecimal = actualFee.decimal(assetInfo: params.assetInfo)

                return viewModelFactory.amountFromValue(
                    targetAssetInfo: params.assetInfo,
                    value: feeDecimal
                ).value(for: locale)
            }

            let errorParams = MultisigNotEnoughForDeposit(
                deposit: depositModel,
                fee: feeModel,
                needToAdd: needToAddModel,
                signatoryName: params.signatoryName
            )

            self?.presentable.presentNotEnoughBalanceForDepositAndFee(
                from: view,
                params: errorParams,
                locale: locale
            )
        }, preservesCondition: {
            guard let deposit = params.deposit else { return false }

            let available = params.balance ?? 0

            return available >= deposit
        })
    }

    func canPayFee(
        params: MultisigFeeValidationParams,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view, let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                return
            }

            let balanceDecimal = params.balance?.decimal(
                assetInfo: params.assetInfo
            ) ?? 0

            let feeDecimal = params.fee?.amountForCurrentAccount?.decimal(
                assetInfo: params.assetInfo
            ) ?? 0

            let needToAddDecimal = feeDecimal - balanceDecimal

            let needToAddModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.assetInfo,
                value: needToAddDecimal
            ).value(for: locale)

            let feeModel = viewModelFactory.amountFromValue(
                targetAssetInfo: params.assetInfo,
                value: feeDecimal
            ).value(for: locale)

            self?.presentable.presentNotEnoughBalanceForFee(
                from: view,
                fee: feeModel,
                needToAdd: needToAddModel,
                signatoryName: params.signatoryName,
                locale: locale
            )

        }, preservesCondition: {
            guard let fee = params.fee?.amountForCurrentAccount else {
                return true
            }

            let available = params.balance ?? 0

            return available >= fee
        })
    }

    func operationNotExists(
        _ noOperation: Bool,
        multisigName: String,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentOperationAlreadyAdded(
                from: view,
                multisigName: multisigName,
                locale: locale
            )
        }, preservesCondition: {
            noOperation
        })
    }
}
