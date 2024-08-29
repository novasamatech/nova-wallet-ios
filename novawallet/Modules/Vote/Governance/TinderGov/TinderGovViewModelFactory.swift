import Foundation

protocol TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        for referendums: [ReferendumLocal]?,
        accountVotes: ReferendumAccountVotingDistribution?,
        locale: Locale
    ) -> ReferendumsSection?
}

struct TinderGovViewModelFactory: TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        for referendums: [ReferendumLocal]?,
        accountVotes: ReferendumAccountVotingDistribution?,
        locale: Locale
    ) -> ReferendumsSection? {
        guard let referendums else {
            return nil
        }

        let tinderGovReferenda = referendums.filter {
            $0.canVote && (accountVotes?.votes[$0.index] == nil)
        }

        let section: ReferendumsSection? = {
            guard !tinderGovReferenda.isEmpty else {
                return nil
            }

            return .tinderGov(
                TinderGovBannerViewModel(
                    title: R.string.localizable.commonTinderGov(preferredLanguages: locale.rLanguages),
                    description: R.string.localizable.tinderGovBannerMessage(
                        preferredLanguages: locale.rLanguages
                    ),
                    referendumCounterText: R.string.localizable.commonCountedReferenda(
                        tinderGovReferenda.count,
                        preferredLanguages: locale.rLanguages
                    )
                )
            )
        }()

        return section
    }
}
