import Foundation
import SoraFoundation

protocol EndedReferendumProgressViewModelFactoryProtocol {
    func createProgressViewModel(
        votingAmount: ReferendumVotingAmount?,
        locale: Locale
    ) -> VotingProgressView.Model?
}

final class EndedReferendumProgressViewModelFactory: EndedReferendumProgressViewModelFactoryProtocol {
    let localizedPercentFormatter: LocalizableResource<NumberFormatter>

    init(localizedPercentFormatter: LocalizableResource<NumberFormatter>) {
        self.localizedPercentFormatter = localizedPercentFormatter
    }

    func createProgressViewModel(
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
