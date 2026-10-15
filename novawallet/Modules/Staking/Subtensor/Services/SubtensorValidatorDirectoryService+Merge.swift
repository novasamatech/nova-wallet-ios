import Foundation

extension SubtensorValidatorDirectoryService {
    struct Row {
        let hotkey: AccountId
        let name: String?
        let stake: BigRational?
    }

    struct Listing {
        let rows: [Row]
        let listStamp: SubtensorBackendStamp?
        let isPartial: Bool
    }

    static func makeListing(
        from response: BittensorApiResult<BittensorApi.ValidatorCollection>,
        netuid: UInt16,
        logger: LoggerProtocol
    ) -> Listing {
        let collection = response.value
        let candidates = collection.items.filter { $0.netuid == netuid }

        let rows = candidates.compactMap { item in
            makeRow(
                hotkey: item.hotkey,
                name: nonBlank(item.identitySourceName) ?? nonBlank(item.stakeSourceName),
                stake: reportedStake(item.reportedMeasurements.validatorStake)
            )
        }

        if rows.count < candidates.count {
            logger.warning("Dropped \(candidates.count - rows.count) validator rows of netuid \(netuid)")
        }

        let components = collection.meta.components

        let stamps = [
            components.validatorStakes,
            components.validatorMetagraph,
            components.validatorIdentities
        ].compactMap { SubtensorBackendStamp(metadata: $0, isFromExpiredCache: response.isFromExpiredCache) }

        return Listing(
            rows: rows,
            listStamp: SubtensorBackendStamp.aggregate(stamps),
            isPartial: collection.meta.completeness == .partial
        )
    }

    static func makeRootListing(
        from response: BittensorApiResult<BittensorApi.RootValidatorCollection>,
        logger: LoggerProtocol
    ) -> Listing {
        let collection = response.value

        let candidates = collection.items.filter { (reportedStake($0.rootStakeTao)?.numerator ?? 0) > 0 }

        let rows = candidates.compactMap { item in
            makeRow(hotkey: item.hotkey, name: nonBlank(item.name), stake: reportedStake(item.rootStakeTao))
        }

        if rows.count < candidates.count {
            logger.warning("Dropped \(candidates.count - rows.count) root validator rows")
        }

        return Listing(
            rows: rows,
            listStamp: SubtensorBackendStamp(
                component: collection.meta.components.rootValidators,
                isFromExpiredCache: response.isFromExpiredCache
            ),
            isPartial: false
        )
    }

    static func makeRow(hotkey: String, name: String?, stake: BigRational?) -> Row? {
        guard let accountId = try? hotkey.toAccountId(using: .substrate(SubstrateConstants.genericAddressPrefix)) else {
            return nil
        }

        return Row(hotkey: accountId, name: name, stake: stake)
    }

    static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    static func reportedStake(_ value: String?) -> BigRational? {
        value.flatMap { try? BittensorApiDecimal.fraction($0) }
    }

    static func makeDirectory(subnet: SubtensorSubnetRef, listing: Listing) -> SubtensorValidatorDirectory {
        SubtensorValidatorDirectory(
            subnet: subnet,
            items: listing.rows.map { row in
                SubtensorValidatorDirectoryItem(
                    hotkey: row.hotkey,
                    netuid: subnet.netuid,
                    name: row.name,
                    take: nil,
                    reportedStake: row.stake,
                    status: nil
                )
            },
            listStamp: listing.listStamp,
            isPartial: listing.isPartial
        )
    }
}
