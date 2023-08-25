import SoraFoundation

protocol NominationPoolDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func nominationPoolHasApy(
        method: StakingSelectionMethod,
        locale: Locale
    ) -> DataValidating
}

final class NominationPoolDataValidatorFactory {
    weak var view: (ControllerBackedProtocol & Localizable)?
    let presentable: NominationPoolErrorPresentable
    var basePresentable: BaseErrorPresentable { presentable }

    init(presentable: NominationPoolErrorPresentable) {
        self.presentable = presentable
    }
}

extension NominationPoolDataValidatorFactory: NominationPoolDataValidatorFactoryProtocol {
    func nominationPoolHasApy(
        method: StakingSelectionMethod,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentNominationPoolHasNoApy(
                from: view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard case let .pool(selectedPool) = method.selectedStakingOption else {
                return true
            }

            if let apy = selectedPool.maxApy, apy > 0 {
                return true
            } else {
                return false
            }
        })
    }
}
