import Foundation

enum AssetExchangeCommissionConstants {
    static let rate = BigRational(numerator: 85, denominator: 10000)

    static let hydrationBeneficiaryAddress = "15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh"

    static let assetHubBeneficiaryAddress = "15WGd8nfLawEAZcMjrWecJ3ngofF3UzTVU2YQjt4PApf6JCR"

    static let assetHubBeneficiaryAddresses: [ChainModel.Id: AccountAddress] = [:]

    static let historicalAssetHubBeneficiaryAddresses: [ChainModel.Id: [AccountAddress]] = [:]

    static func assetHubHistoryBeneficiaries(for chainId: ChainModel.Id) -> Set<AccountId> {
        let current = assetHubBeneficiaryAddresses[chainId].map { [$0] } ?? []
        let historical = historicalAssetHubBeneficiaryAddresses[chainId] ?? []

        return Set((current + historical).compactMap { try? $0.toAccountId() })
    }
}

extension BigRational {
    var asShareOfGross: BigRational {
        BigRational(numerator: numerator, denominator: denominator + numerator)
    }
}
