import Foundation
import Foundation_iOS

final class MythosStakingValidationFactory {
    weak var view: ControllerBackedProtocol?

    var collatorStakingPresentable: CollatorStakingErrorPresentable { presentable }
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let presentable: MythosStakingErrorPresentable

    private(set) lazy var balanceViewModelFactory: BalanceViewModelFactoryProtocol = BalanceViewModelFactory(
        targetAssetInfo: assetDisplayInfo,
        priceAssetInfoFactory: priceAssetInfoFactory
    )

    private(set) lazy var quantityFormatter = NumberFormatter.quantity.localizableResource()

    init(
        presentable: MythosStakingErrorPresentable,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.presentable = presentable
        self.assetDisplayInfo = assetDisplayInfo
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }
}

extension MythosStakingValidationFactory: MythosStakingValidationFactoryProtocol {
    func notExceedsMaxUnstakingItems(
        unstakingItemsCount: Int,
        maxUnstakingItemsAllowed: UInt32?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let maxAllowed = self?.quantityFormatter.value(for: locale).string(
                from: NSNumber(value: maxUnstakingItemsAllowed ?? 0)
            )

            self?.presentable.presentUnstakingItemsLimitReached(
                view,
                maxAllowed: maxAllowed ?? "",
                locale: locale
            )

        }, preservesCondition: {
            guard let maxUnstakingItemsAllowed else {
                return true
            }

            return UInt32(unstakingItemsCount) < maxUnstakingItemsAllowed
        })
    }
}
