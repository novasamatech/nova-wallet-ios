import Foundation

enum AssetExchangeCommissionConstants {
    static let rate = BigRational(numerator: 85, denominator: 10000)

    static let hydrationBeneficiaryAddress = "15ReoCRFgpGXjuaFXzGv7qaqiRrFE5uEMGVC7tBQhaWfzXh"

    static let assetHubBeneficiaryAddress = "15WGd8nfLawEAZcMjrWecJ3ngofF3UzTVU2YQjt4PApf6JCR"

    static let assetHubBeneficiaryAddresses: [ChainModel.Id: AccountAddress] = [
        KnowChainId.polkadotAssetHub: assetHubBeneficiaryAddress
    ]

    static let historicalAssetHubBeneficiaryAddresses: [ChainModel.Id: [AccountAddress]] = [:]

    struct HistoryBeneficiaries {
        let accountIds: Set<AccountId>
        let invalid: [AccountAddress]
    }

    static func historyBeneficiaries(
        current: [AccountAddress],
        historical: [AccountAddress]
    ) -> HistoryBeneficiaries {
        var accountIds: Set<AccountId> = []
        var invalid: [AccountAddress] = []

        for address in current + historical {
            if
                let accountId = try? address.toAccountId(),
                accountId.count == SubstrateConstants.accountIdLength {
                accountIds.insert(accountId)
            } else {
                invalid.append(address)
            }
        }

        return HistoryBeneficiaries(accountIds: accountIds, invalid: invalid)
    }

    static func assetHubHistoryBeneficiaries(for chainId: ChainModel.Id) -> HistoryBeneficiaries {
        historyBeneficiaries(
            current: assetHubBeneficiaryAddresses[chainId].map { [$0] } ?? [],
            historical: historicalAssetHubBeneficiaryAddresses[chainId] ?? []
        )
    }
}

extension BigRational {
    var asShareOfGross: BigRational {
        BigRational(numerator: numerator, denominator: denominator + numerator)
    }
}
