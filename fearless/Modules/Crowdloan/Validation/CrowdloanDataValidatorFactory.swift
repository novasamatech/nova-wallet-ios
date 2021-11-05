import Foundation
import SoraFoundation
import BigInt
import CommonWallet

protocol CrowdloanDataValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func contributesAtLeastMinContribution(
        contribution: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func capNotExceeding(
        contribution: BigUInt?,
        raised: BigUInt?,
        cap: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func crowdloanIsNotCompleted(
        crowdloan: Crowdloan?,
        metadata: CrowdloanMetadata?,
        locale: Locale
    ) -> DataValidating

    func crowdloanIsNotPrivate(
        crowdloan: Crowdloan?,
        displayInfo: CrowdloanDisplayInfo?,
        locale: Locale
    ) -> DataValidating

    func hasAppliedReferralCode(
        bonusService: CrowdloanBonusServiceProtocol?,
        locale: Locale,
        action: @escaping (Bool) -> Void
    ) -> DataValidating
}

final class CrowdloanDataValidatingFactory: CrowdloanDataValidatorFactoryProtocol {
    weak var view: (ControllerBackedProtocol & Localizable)?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: CrowdloanErrorPresentable
    let assetInfo: AssetBalanceDisplayInfo
    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        presentable: CrowdloanErrorPresentable,
        assetInfo: AssetBalanceDisplayInfo,
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.presentable = presentable
        self.assetInfo = assetInfo
        self.amountFormatterFactory = amountFormatterFactory
    }

    func contributesAtLeastMinContribution(
        contribution: BigUInt?,
        minimumBalance: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let strongSelf = self, let view = strongSelf.view else {
                return
            }

            let formatter = strongSelf.amountFormatterFactory.createDisplayFormatter(
                for: strongSelf.assetInfo
            ).value(for: locale)

            let minimumBalanceString = minimumBalance
                .map { Decimal.fromSubstrateAmount($0, precision: strongSelf.assetInfo.assetPrecision) }?
                .map { formatter.stringFromDecimal($0) } ?? nil

            self?.presentable.presentMinimalBalanceContributionError(
                minimumBalanceString ?? "",
                from: view,
                locale: locale
            )

        }, preservesCondition: {
            if let contribution = contribution,
               let minimumBalance = minimumBalance {
                return contribution >= minimumBalance
            } else {
                return false
            }
        })
    }

    func capNotExceeding(
        contribution: BigUInt?,
        raised: BigUInt?,
        cap: BigUInt?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let strongSelf = self, let view = strongSelf.view else {
                return
            }

            if let raised = raised,
               let cap = cap,
               cap > raised {
                let decimalDiff = Decimal.fromSubstrateAmount(
                    cap - raised,
                    precision: strongSelf.assetInfo.assetPrecision
                )

                let diffString = decimalDiff.map {
                    strongSelf.amountFormatterFactory.createDisplayFormatter(for: strongSelf.assetInfo)
                        .value(for: locale)
                        .stringFromDecimal($0)
                } ?? nil

                self?.presentable.presentAmountExceedsCapError(diffString ?? "", from: view, locale: locale)

            } else {
                self?.presentable.presentCapReachedError(from: view, locale: locale)
            }

        }, preservesCondition: {
            if let contribution = contribution,
               let raised = raised,
               let cap = cap {
                return raised + contribution <= cap
            } else {
                return false
            }
        })
    }

    func crowdloanIsNotCompleted(
        crowdloan: Crowdloan?,
        metadata: CrowdloanMetadata?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCrowdloanEnded(from: view, locale: locale)

        }, preservesCondition: {
            if let crowdloan = crowdloan,
               let metadata = metadata {
                return !crowdloan.isCompleted(for: metadata)
            } else {
                return false
            }
        })
    }

    func crowdloanIsNotPrivate(
        crowdloan: Crowdloan?,
        displayInfo: CrowdloanDisplayInfo?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentCrowdloanPrivateNotSupported(from: view, locale: locale)

        }, preservesCondition: {
            let isPublic = crowdloan?.fundInfo.verifier == nil
            let supportsPrivate = displayInfo?.customFlow?.supportsPrivateCrowdloans ?? false
            return isPublic || supportsPrivate
        })
    }

    func hasAppliedReferralCode(
        bonusService: CrowdloanBonusServiceProtocol?,
        locale: Locale,
        action: @escaping (Bool) -> Void
    ) -> DataValidating {
        WarningConditionViolation(
            onWarning: { [weak self] delegate in
                guard let view = self?.view else {
                    return
                }
                self?.presentable.presentHaveNotAppliedBonusWarning(from: view, locale: locale) { apply in
                    action(apply)
                    if !apply {
                        delegate.didCompleteWarningHandling()
                    }
                }
            },
            preservesCondition: {
                guard let service = bonusService else { return true }
                if service.referralCode != nil {
                    return true
                } else if service.defaultReferralCode != nil {
                    return false
                } else {
                    return true
                }
            }
        )
    }
}
