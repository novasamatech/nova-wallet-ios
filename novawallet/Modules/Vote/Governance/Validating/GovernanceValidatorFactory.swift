import Foundation
import BigInt
import Foundation_iOS

protocol GovernanceValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func enoughTokensForVoting(
        _ assetBalance: AssetBalance?,
        votingAmount: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        maxAmountErrorClosure: ((BigUInt) -> Void)?,
        locale: Locale?
    ) -> DataValidating

    func enoughTokensForVotingAndFee(
        _ params: GovMaxAmountValidatingParams,
        maxAmountErrorClosure: ((BigUInt) -> Void)?,
        locale: Locale?
    ) -> DataValidating

    func referendumNotEnded(
        _ referendum: ReferendumLocal?,
        includesIndex: Bool,
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

    func notSelfDelegating(
        selfId: AccountId?,
        delegateId: AccountId?,
        locale: Locale?
    ) -> DataValidating

    func notVoting(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        tracks: Set<TrackIdLocal>?,
        locale: Locale?
    ) -> DataValidating

    func delegating(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        tracks: Set<TrackIdLocal>?,
        delegateId: AccountId?,
        locale: Locale?
    ) -> DataValidating

    func voteMatchesConviction(
        with newVote: ReferendumNewVote?,
        selectedConviction: ConvictionVoting.Conviction?,
        convictionUpdateClosure: (() -> Void)?,
        locale: Locale?
    ) -> DataValidating
}

final class GovernanceValidatorFactory {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let quantityFormatter: LocalizableResource<NumberFormatter>
    let presentable: GovernanceErrorPresentable
    let govBalanceCalculator: AvailableBalanceMapping

    init(
        presentable: GovernanceErrorPresentable,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        govBalanceCalculator: AvailableBalanceMapping
    ) {
        self.presentable = presentable
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.quantityFormatter = quantityFormatter
        self.govBalanceCalculator = govBalanceCalculator
    }
}

extension GovernanceValidatorFactory: GovernanceValidatorFactoryProtocol {
    func enoughTokensForVoting(
        _ assetBalance: AssetBalance?,
        votingAmount: BigUInt?,
        assetInfo: AssetBalanceDisplayInfo,
        maxAmountErrorClosure: ((BigUInt) -> Void)?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let amountFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: assetInfo)
            let availableForOpenGov = govBalanceCalculator.availableBalanceElseZero(from: assetBalance)

            let amountDecimal = availableForOpenGov.decimal(assetInfo: assetInfo)
            let amountString = amountFormatter.value(for: locale ?? Locale.current).stringFromDecimal(
                amountDecimal
            ) ?? ""

            if let maxAmountErrorClosure, availableForOpenGov > 0 {
                presentable.presentNotEnoughTokensToVote(
                    from: view,
                    available: amountString,
                    maxAction: {
                        maxAmountErrorClosure(availableForOpenGov)
                    },
                    locale: locale
                )
            } else {
                presentable.presentNotEnoughTokensToVote(
                    from: view,
                    available: amountString,
                    maxAction: nil,
                    locale: locale
                )
            }
        }, preservesCondition: { [weak self] in
            guard
                let availableBalance = self?.govBalanceCalculator.mapAvailableBalance(
                    from: assetBalance
                ),
                let votingAmount = votingAmount else {
                return false
            }

            return availableBalance >= votingAmount
        })
    }

    func enoughTokensForVotingAndFee(
        _ params: GovMaxAmountValidatingParams,
        maxAmountErrorClosure: ((BigUInt) -> Void)?,
        locale: Locale?
    ) -> DataValidating {
        let availableForFee: BigUInt = if
            let availableAmount = govBalanceCalculator.mapAvailableBalance(from: params.assetBalance),
            let transferrableAmont = params.assetBalance?.transferable,
            let votingAmount = params.votingAmount {
            min(availableAmount.subtractOrZero(votingAmount), transferrableAmont)
        } else {
            0
        }

        return ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let amountFormatter = assetBalanceFormatterFactory.createTokenFormatter(
                for: params.assetInfo
            ).value(for: locale ?? Locale.current)

            let feeInPlank = params.fee?.amountForCurrentAccount ?? 0
            let transferableInPlank = params.assetBalance?.transferable ?? 0
            let availableForGov = govBalanceCalculator.availableBalanceElseZero(from: params.assetBalance)
            let availableAfterFee = transferableInPlank >= feeInPlank ?
                availableForGov.subtractOrZero(feeInPlank) : 0

            let amountDecimal = availableAfterFee.decimal(assetInfo: params.assetInfo)
            let amountString = amountFormatter.stringFromDecimal(amountDecimal) ?? ""

            let feeDecimal = feeInPlank.decimal(assetInfo: params.assetInfo)
            let feeString = amountFormatter.stringFromDecimal(feeDecimal) ?? ""

            if let maxAmountErrorClosure, availableAfterFee > 0 {
                presentable.presentUpToForFee(
                    from: view,
                    available: amountString,
                    fee: feeString,
                    maxClosure: {
                        maxAmountErrorClosure(availableAfterFee)
                    },
                    locale: locale
                )
            } else {
                presentable.presentUpToForFee(
                    from: view,
                    available: amountString,
                    fee: feeString,
                    maxClosure: nil,
                    locale: locale
                )
            }

        }, preservesCondition: {
            guard let fee = params.fee?.amountForCurrentAccount else {
                return true
            }

            return availableForFee >= fee
        })
    }

    func referendumNotEnded(
        _ referendum: ReferendumLocal?,
        includesIndex: Bool,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentReferendumCompleted(
                from: view,
                referendumId: includesIndex ? referendum?.index : nil,
                locale: locale
            )
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

    func notVoting(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        tracks: Set<TrackIdLocal>?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentAlreadyVoting(from: view, locale: locale)
        }, preservesCondition: {
            guard let voting = accountVotingDistribution, let tracks = tracks else {
                return false
            }

            let votedTracks = Set(voting.votedTracks.keys)

            return !tracks.isEmpty && tracks.isDisjoint(with: votedTracks)
        })
    }

    func delegating(
        _ accountVotingDistribution: ReferendumAccountVotingDistribution?,
        tracks: Set<TrackIdLocal>?,
        delegateId: AccountId?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentAlreadyRevokedDelegation(from: view, locale: locale)
        }, preservesCondition: {
            guard let voting = accountVotingDistribution, let tracks = tracks else {
                return false
            }

            let delegatingTracks = voting.delegatings.filter { $0.value.target == delegateId }.map(\.key)

            return !tracks.isEmpty && tracks.isSubset(of: delegatingTracks)
        })
    }

    func voteMatchesConviction(
        with newVote: ReferendumNewVote?,
        selectedConviction: ConvictionVoting.Conviction?,
        convictionUpdateClosure: (() -> Void)?,
        locale: Locale?
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let view = self?.view else {
                return
            }

            self?.presentable.presentConvictionUpdateRequired(
                from: view,
                action: {
                    convictionUpdateClosure?()
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let newVote, let selectedConviction else {
                return false
            }
            if case .abstain = newVote.voteAction {
                return selectedConviction == .none
            } else {
                return true
            }
        })
    }
}

extension GovernanceValidatorFactory {
    static func createFromPresentable(
        _ presentable: GovernanceErrorPresentable,
        govType: GovernanceType
    ) -> GovernanceValidatorFactory {
        GovernanceValidatorFactory(
            presentable: presentable,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            govBalanceCalculator: GovernanceBalanceCalculator(governanceType: govType)
        )
    }
}
