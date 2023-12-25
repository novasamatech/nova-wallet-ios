import Foundation
import BigInt

enum Pdc20NftModelConverter {
    struct ListingId: Hashable {
        let tokenId: String
        let address: String
    }

    struct ListingAggregate {
        let amount: BigUInt
        let value: Decimal

        init(amount: BigUInt = 0, value: Decimal = 0) {
            self.amount = amount
            self.value = value
        }

        func addingNew(listing: Pdc20NftRemoteListing) -> ListingAggregate {
            guard let newValue = Decimal(string: listing.value) else {
                return self
            }

            return .init(
                amount: amount + listing.amount,
                value: value + newValue
            )
        }
    }

    static func convert(response: Pdc20NftResponse, chain: ChainModel) throws -> [RemoteNftModel] {
        let aggregatedListing = response.listings.reduce(into: [ListingId: ListingAggregate]()) { accum, nextValue in
            let listingId = ListingId(tokenId: nextValue.token.identifier, address: nextValue.from.address)
            let current = accum[listingId] ?? ListingAggregate()
            accum[listingId] = current.addingNew(listing: nextValue)
        }

        return try response.userTokenBalances.map { tokenBalance in
            let identifier = NftModel.pdc20Identifier(
                for: chain.chainId,
                token: tokenBalance.token.identifier,
                address: tokenBalance.address.address
            )

            let accountId = try tokenBalance.address.address.toAccountId(using: chain.chainFormat)

            let listingId = ListingId(
                tokenId: tokenBalance.token.identifier,
                address: tokenBalance.address.address
            )

            let listing = aggregatedListing[listingId]

            let price: String? = listing.flatMap {
                guard
                    let assetInfo = chain.utilityChainAsset()?.assetDisplayInfo,
                    let value = $0.value.toSubstrateAmount(precision: assetInfo.assetPrecision) else {
                    return nil
                }

                return String(value)
            }

            return RemoteNftModel(
                identifier: identifier,
                type: NftType.pdc20.rawValue,
                chainId: chain.chainId,
                ownerId: accountId,
                collectionId: tokenBalance.token.identifier,
                instanceId: tokenBalance.token.identifier,
                metadata: nil,
                issuanceTotal: tokenBalance.token.totalSupply,
                issuanceMyAmount: tokenBalance.balance,
                name: tokenBalance.token.ticker,
                label: nil,
                media: tokenBalance.token.logo,
                price: price,
                priceUnits: listing.flatMap { String($0.amount) }
            )
        }
    }
}
