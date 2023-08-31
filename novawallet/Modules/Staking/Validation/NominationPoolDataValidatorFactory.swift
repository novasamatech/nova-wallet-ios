import SoraFoundation

protocol NominationPoolDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func nominationPoolHasApy(
        method: StakingSelectionMethod,
        locale: Locale
    ) -> DataValidating
    func nominationPoolIsDestroing(
        pool: NominationPools.BondedPool?,
        locale: Locale
    ) -> DataValidating
    func nominationPoolIsFullyUnbonding(
        poolMember: NominationPools.PoolMember?,
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

    func nominationPoolIsDestroing(
        pool: NominationPools.BondedPool?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentNominationPoolIsDestroing(
                from: view,
                locale: locale
            )
        }, preservesCondition: {
            guard let pool = pool else {
                return false
            }
            return pool.state != .destroying
        })
    }

    func nominationPoolIsFullyUnbonding(
        poolMember: NominationPools.PoolMember?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }
            self?.presentable.presentPoolIsFullyUnbonding(from: view, locale: locale)
        }, preservesCondition: {
            guard let poolMember = poolMember else {
                return false
            }
            return poolMember.points > 0
        })
    }
}
