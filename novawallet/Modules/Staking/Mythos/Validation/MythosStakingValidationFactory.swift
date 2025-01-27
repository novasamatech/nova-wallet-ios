import Foundation
import SoraFoundation

final class MythosStakingValidationFactory: MythosStakingValidationFactoryProtocol {
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

extension MythosStakingValidationFactory {
    func noUnclaimedRewards(
        _ hasUnclaimedRewards: Bool,
        claimAction: @escaping () -> Void,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentUnclaimedRewards(view, claimAction: claimAction, locale: locale)
        }, preservesCondition: {
            !hasUnclaimedRewards
        })
    }
}
