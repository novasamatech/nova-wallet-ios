import Foundation

protocol TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        using filter: TinderGovReferendumsFilter,
        locale: Locale
    ) -> ReferendumsSection?

    func createVoteCardViewModels(from referendums: [ReferendumLocal]) -> [VoteCardViewModel]
}

struct TinderGovViewModelFactory {
    private let cardGradientFactory = TinderGovGradientFactory()
}

extension TinderGovViewModelFactory: TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        using filter: TinderGovReferendumsFilter,
        locale: Locale
    ) -> ReferendumsSection? {
        let tinderGovReferenda = filter()

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

    func createVoteCardViewModels(from referendums: [ReferendumLocal]) -> [VoteCardViewModel] {
        referendums.enumerated().map { index, referendum in
            let gradientModel = cardGradientFactory.createCardGratient(for: index)

            return VoteCardViewModel(
                referendum: referendum,
                gradient: gradientModel
            )
        }
    }
}
