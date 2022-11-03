import Foundation
import BigInt
import SoraFoundation

protocol GovernanceValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func enoughTokensForVoting(
        _ assetBalance: AssetBalance?,
        votingAmount: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating

    func enoughTokensForVotingAndFee(
        _ assetBalance: AssetBalance?,
        votingAmount: BigUInt?,
        fee: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating

    func referendumNotEnded(
        _ referendum: ReferendumLocal?,
        locale: Locale?
    ) -> DataValidating

    func notDelegating(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        track: TrackIdLocal?,
        locale: Locale?
    ) -> DataValidating

    func maxVotesNotReached(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        track: TrackIdLocal?,
        locale: Locale?
    ) -> DataValidating
}

final class GovernanceValidatorFactory {
    weak var view: (Localizable & ControllerBackedProtocol)?

    var basePresentable: BaseErrorPresentable { presentable }
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let presentable: GovernanceErrorPresentable

    init(
        presentable: GovernanceErrorPresentable,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.presentable = presentable
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.quantityFormatter = quantityFormatter
    }
}

extension GovernanceValidatorFactory: GovernanceValidatorFactoryProtocol {
    func enoughTokensForVoting(
        _ assetBalance: AssetBalance?,
        votingAmount: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let amountFormatter = self?.assetBalanceFormatterFactory.createTokenFormatter(for: assetInfo)
            let amountString: String

            if
                let freeInPlank = assetBalance?.freeInPlank,
                let amountDecimal = Decimal.fromSubstrateAmount(freeInPlank, precision: assetInfo.assetPrecision) {
                amountString = amountFormatter?.value(for: locale ?? Locale.current).stringFromDecimal(
                    amountDecimal
                ) ?? ""
            } else {
                amountString = ""
            }

            self?.presentable.presentNotEnoughTokensToVote(
                from: view,
                available: amountString,
                locale: locale
            )
        }, preservesCondition: {
            guard
                let assetBalance = assetBalance,
                let votingAmount = votingAmount else {
                return false
            }

            return assetBalance.freeInPlank >= votingAmount
        })
    }

    func enoughTokensForVotingAndFee(
        _ assetBalance: AssetBalance?,
        votingAmount: BigUInt?,
        fee: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        locale: Locale?
    ) -> DataValidating {
        let availableForFee: BigUInt

        if
            let assetBalance = assetBalance,
            let votingAmount = votingAmount,
            assetBalance.freeInPlank >= votingAmount {
            availableForFee = min(assetBalance.freeInPlank - votingAmount, assetBalance.transferable)
        } else {
            availableForFee = 0
        }

        return ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            let amountFormatter = self?.assetBalanceFormatterFactory.createTokenFormatter(
                for: assetInfo
            ).value(for: locale ?? Locale.current)

            let amountString: String

            if
                let amountDecimal = Decimal.fromSubstrateAmount(
                    availableForFee,
                    precision: assetInfo.assetPrecision
                ) {
                amountString = amountFormatter?.stringFromDecimal(amountDecimal) ?? ""
            } else {
                amountString = ""
            }

            let feeString: String

            if
                let feeDecimal = Decimal.fromSubstrateAmount(
                    fee ?? 0,
                    precision: assetInfo.assetPrecision
                ) {
                feeString = amountFormatter?.stringFromDecimal(feeDecimal) ?? ""
            } else {
                feeString = ""
            }

            self?.presentable.presentFeeTooHigh(from: view, balance: amountString, fee: feeString, locale: locale)
        }, preservesCondition: {
            guard let fee = fee else {
                return true
            }

            return availableForFee >= fee
        })
    }

    func referendumNotEnded(_ referendum: ReferendumLocal?, locale: Locale?) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentReferendumCompleted(from: view, locale: locale)
        }, preservesCondition: {
            guard let referendum = referendum else {
                return false
            }

            return referendum.canVote
        })
    }

    func notDelegating(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        track: TrackIdLocal?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentAlreadyDelegatingVotes(from: view, locale: locale)
        }, preservesCondition: {
            guard let track = track else {
                return true
            }

            return accountVotingDistribution?.delegatings[track] == nil
        })
    }

    func maxVotesNotReached(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        track: TrackIdLocal?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view, let accountVotingDistribution = accountVotingDistribution else {
                return
            }

            let allowed = self?.quantityFormatter.value(
                for: locale ?? Locale.current
            ).string(from: accountVotingDistribution.maxVotesPerTrack as NSNumber)

            self?.presentable.presentVotesMaximumNumberReached(from: view, allowed: allowed ?? "", locale: locale)
        }, preservesCondition: {
            guard
                let track = track,
                let accountVotingDistribution = accountVotingDistribution else {
                return true
            }

            let numberOfVotes = accountVotingDistribution.votedTracks[track]?.count ?? 0

            return numberOfVotes < Int(accountVotingDistribution.maxVotesPerTrack)
        })
    }
}
