import Foundation
import BigInt

protocol DelegationsDisplayStringFactoryProtocol {
    func createVotesDetailsInMultipleTracks(count: Int, locale: Locale) -> String?
    func createVotesValue(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String?
    func createVotes(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String?
    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain: ChainModel,
        locale: Locale
    ) -> String?
}

final class DelegationsDisplayStringFactory: DelegationsDisplayStringFactoryProtocol {
    let referendumDisplayStringFactory: ReferendumDisplayStringFactoryProtocol

    init(referendumDisplayStringFactory: ReferendumDisplayStringFactoryProtocol) {
        self.referendumDisplayStringFactory = referendumDisplayStringFactory
    }

    func createVotesDetailsInMultipleTracks(count: Int, locale: Locale) -> String? {
        R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.delegationsListMultipleTracks(
            "\(count)"
        )
    }

    func createVotesValue(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        referendumDisplayStringFactory.createVotesValue(from: votes, chain: chain, locale: locale)
    }

    func createVotes(from votes: BigUInt, chain: ChainModel, locale: Locale) -> String? {
        referendumDisplayStringFactory.createVotes(from: votes, chain: chain, locale: locale)
    }

    func createVotesDetails(
        from amount: BigUInt,
        conviction: Decimal?,
        chain: ChainModel,
        locale: Locale
    ) -> String? {
        referendumDisplayStringFactory.createVotesDetails(
            from: amount,
            conviction: conviction,
            chain: chain,
            locale: locale
        )
    }
}
