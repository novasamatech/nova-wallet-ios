import Foundation
import BigInt
import SoraFoundation

protocol ProxyDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func hasSufficientBalance(
        available: BigUInt?,
        deposit: BigUInt?,
        fee: BigUInt?,
        asset: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> DataValidating

    func validAddress(
        _ address: String,
        chain: ChainModel,
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
        available: BigUInt?,
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
            let balanceDecimal = available?.decimal(assetInfo: asset)
            let depositDecimal = deposit?.decimal(assetInfo: asset)

            let balanceModel = viewModelFactory.amountFromValue(
                targetAssetInfo: asset,
                value: balanceDecimal ?? 0
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
                  let fee = fee,
                  let available = available else {
                return false
            }
            return available >= deposit + fee
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
            return proxyCount < limit
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
            return proxyList.contains(where: { $0.proxy == accountId }) == false
        })
    }
}
