import Foundation
import BigInt
import Foundation_iOS

protocol ProxyDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasSufficientBalance(
        available: BigUInt,
        deposit: BigUInt?,
        fee: BigUInt?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func notReachedMaximimProxyCount(
        _ proxyCount: Int?,
        limit: Int?,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating

    func proxyNotExists(
        address: String,
        chain: ChainModel,
        proxyList: [Proxy.ProxyDefinition]?,
        locale: Locale
    ) -> DataValidating

    func validAddress(
        _ address: String,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating

    func canPayFee(
        balance: Decimal?,
        fee: ExtrinsicFeeProtocol?,
        proxyName: String,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func notSelfDelegating(
        selfId: AccountId?,
        delegateId: AccountId?,
        locale: Locale?
    ) -> DataValidating
}

extension ProxyDataValidatorFactoryProtocol {
    func canPayFeeInPlank(
        balance: BigUInt?,
        fee: ExtrinsicFeeProtocol?,
        proxyName: String,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        let precision = asset.assetPrecision
        let balanceDecimal = balance.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }

        return canPayFee(
            balance: balanceDecimal,
            fee: fee,
            proxyName: proxyName,
            asset: asset,
            locale: locale
        )
    }
}

final class ProxyDataValidatorFactory: ProxyDataValidatorFactoryProtocol {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }
    let presentable: ProxyErrorPresentable
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(
        presentable: ProxyErrorPresentable,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.presentable = presentable
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }

    func hasSufficientBalance(
        available: BigUInt,
        deposit: BigUInt?,
        fee: BigUInt?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard
                let view = self?.view,
                let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                return
            }
            let balanceDecimal = available.decimal(assetInfo: asset)
            let depositDecimal = deposit?.decimal(assetInfo: asset)

            let balanceModel = viewModelFactory.amountFromValue(
                targetAssetInfo: asset,
                value: balanceDecimal
            ).value(for: locale)
            let depositModel = viewModelFactory.amountFromValue(
                targetAssetInfo: asset,
                value: depositDecimal ?? 0
            ).value(for: locale)

            self?.presentable.presentNotEnoughBalanceForDeposit(
                from: view,
                deposit: depositModel,
                balance: balanceModel,
                locale: locale
            )
        }, preservesCondition: {
            guard let deposit = deposit,
                  let fee = fee else {
                return false
            }
            return available >= deposit + fee
        })
    }

    func notReachedMaximimProxyCount(
        _ proxyCount: Int?,
        limit: Int?,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let limitNumber = NSNumber(value: limit ?? 0)
            let formatter = NumberFormatter.quantity
            self?.presentable.presentMaximumProxyCount(
                from: view,
                limit: formatter.string(from: limitNumber) ?? "",
                networkName: chain.name,
                locale: locale
            )
        }, preservesCondition: {
            guard let proxyCount = proxyCount,
                  let limit = limit else {
                return false
            }
            return proxyCount <= limit
        })
    }

    func proxyNotExists(
        address: String,
        chain: ChainModel,
        proxyList: [Proxy.ProxyDefinition]?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentProxyAlreadyAdded(
                from: view,
                account: address,
                locale: locale
            )
        }, preservesCondition: {
            guard let proxyList = proxyList else {
                return false
            }
            let accountId = try? address.toAccountId(using: chain.chainFormat)
            return !proxyList.contains(where: { $0.proxy == accountId && $0.proxyType == .staking })
        })
    }

    func validAddress(
        _ address: String,
        chain: ChainModel,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentNotValidAddress(
                from: view,
                networkName: chain.name,
                locale: locale
            )
        }, preservesCondition: {
            let accountId = try? address.toAccountId(using: chain.chainFormat)
            return accountId != nil
        })
    }

    func canPayFee(
        balance: Decimal?,
        fee: ExtrinsicFeeProtocol?,
        proxyName: String,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view, let viewModelFactory = self?.balanceViewModelFactoryFacade else {
                return
            }

            let balanceString = viewModelFactory.amountFromValue(
                targetAssetInfo: asset,
                value: balance ?? 0
            ).value(for: locale)

            let feeDecimal = fee?.amountForCurrentAccount?.decimal(assetInfo: asset)

            let feeString = viewModelFactory.amountFromValue(
                targetAssetInfo: asset,
                value: feeDecimal ?? 0
            ).value(for: locale)

            self?.presentable.presentFeeTooHigh(
                from: view,
                balance: balanceString,
                fee: feeString,
                accountName: proxyName,
                locale: locale
            )

        }, preservesCondition: {
            guard let balance = balance, let fee = fee else {
                return false
            }

            guard let feeAmountInPlank = fee.amountForCurrentAccount else {
                return true
            }

            let feeAmount = feeAmountInPlank.decimal(assetInfo: asset)

            return feeAmount <= balance
        })
    }

    func notSelfDelegating(
        selfId: AccountId?,
        delegateId: AccountId?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentSelfDelegating(from: view, locale: locale)
        }, preservesCondition: {
            selfId != nil && delegateId != nil && selfId != delegateId
        })
    }
}
