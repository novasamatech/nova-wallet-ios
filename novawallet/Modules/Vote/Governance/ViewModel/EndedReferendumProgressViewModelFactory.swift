import Foundation
import Foundation_iOS

protocol EndedReferendumProgressViewModelFactoryProtocol {
    func createLoadableViewModel(
        votingAmount: ReferendumVotingAmount?,
        locale: Locale
    ) -> LoadableViewModelState<VotingProgressView.Model?>
}

final class EndedReferendumProgressViewModelFactory {
    let localizedPercentFormatter: LocalizableResource<NumberFormatter>
    let offchainVotingAvailable: Bool

    init(
        localizedPercentFormatter: LocalizableResource<NumberFormatter>,
        offchainVotingAvailable: Bool
    ) {
        self.localizedPercentFormatter = localizedPercentFormatter
        self.offchainVotingAvailable = offchainVotingAvailable
    }

    private func createViewModel(
        votingAmount: ReferendumVotingAmount?,
        locale: Locale
    ) -> VotingProgressView.Model? {
        guard let votingAmount else {
            return nil
        }

        let percentFormatter = localizedPercentFormatter.value(for: locale)
        let approvalFraction = approvalFraction(for: votingAmount)

        let ayeProgressString: String
        let nayProgressString: String

        if let approvalFraction {
            ayeProgressString = percentFormatter.stringFromDecimal(approvalFraction) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(1 - approvalFraction) ?? ""
        } else {
            ayeProgressString = percentFormatter.stringFromDecimal(0) ?? ""
            nayProgressString = percentFormatter.stringFromDecimal(0) ?? ""
        }

        return .init(
            support: nil,
            approval: .init(
                passThreshold: nil,
                ayeProgress: approvalFraction,
                ayeMessage: ayeProgressString,
                passMessage: nil,
                nayMessage: nayProgressString
            )
        )
    }

    private func approvalFraction(for votingAmount: ReferendumVotingAmount) -> Decimal? {
        guard
            let total = Decimal(votingAmount.aye + votingAmount.nay),
            total > 0,
            let aye = Decimal(votingAmount.aye)
        else {
            return nil
        }

        return aye / total
    }
}

extension EndedReferendumProgressViewModelFactory: EndedReferendumProgressViewModelFactoryProtocol {
    func createLoadableViewModel(
        votingAmount: ReferendumVotingAmount?,
        locale: Locale
    ) -> LoadableViewModelState<VotingProgressView.Model?> {
        guard offchainVotingAvailable else {
            return .loaded(value: nil)
        }

        let progress = createViewModel(
            votingAmount: votingAmount,
            locale: locale
        )

        return if let progress {
            .loaded(value: progress)
        } else {
            .loading
        }
    }
}
