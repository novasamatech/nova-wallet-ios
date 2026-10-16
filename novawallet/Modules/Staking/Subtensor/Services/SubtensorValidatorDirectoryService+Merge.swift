import Foundation

extension SubtensorValidatorDirectoryService {
    static func makeListing(
        from response: BittensorApiResult<BittensorApi.ValidatorCollection>,
        subnet: SubtensorSubnetRef,
        logger: LoggerProtocol
    ) -> SubtensorValidatorDirectory {
        let collection = response.value
        let candidates = collection.items.filter { $0.netuid == subnet.netuid }

        let items = candidates.compactMap { item in
            makeItem(
                hotkey: item.hotkey,
                netuid: subnet.netuid,
                name: nonBlank(item.identitySourceName) ?? nonBlank(item.stakeSourceName),
                stake: reportedStake(item.reportedMeasurements.validatorStake)
            )
        }

        if items.count < candidates.count {
            logger.warning("Dropped \(candidates.count - items.count) validator rows of netuid \(subnet.netuid)")
        }

        let components = collection.meta.components

        let stamps = [
            components.validatorStakes,
            components.validatorMetagraph,
            components.validatorIdentities
        ].compactMap { SubtensorBackendStamp(metadata: $0, isFromExpiredCache: response.isFromExpiredCache) }

        return SubtensorValidatorDirectory(
            subnet: subnet,
            items: items,
            listStamp: SubtensorBackendStamp.aggregate(stamps),
            isPartial: collection.meta.completeness == .partial
        )
    }

    static func makeRootListing(
        from response: BittensorApiResult<BittensorApi.RootValidatorCollection>,
        subnet: SubtensorSubnetRef,
        logger: LoggerProtocol
    ) -> SubtensorValidatorDirectory {
        let collection = response.value

        let candidates = collection.items.filter { (reportedStake($0.rootStakeTao)?.numerator ?? 0) > 0 }

        let items = candidates.compactMap { item in
            makeItem(
                hotkey: item.hotkey,
                netuid: subnet.netuid,
                name: nonBlank(item.name),
                stake: reportedStake(item.rootStakeTao)
            )
        }

        if items.count < candidates.count {
            logger.warning("Dropped \(candidates.count - items.count) root validator rows")
        }

        return SubtensorValidatorDirectory(
            subnet: subnet,
            items: items,
            listStamp: SubtensorBackendStamp(
                component: collection.meta.components.rootValidators,
                isFromExpiredCache: response.isFromExpiredCache
            ),
            isPartial: false
        )
    }

    static func makeItem(
        hotkey: String,
        netuid: UInt16,
        name: String?,
        stake: BigRational?
    ) -> SubtensorValidatorDirectoryItem? {
        guard let accountId = try? hotkey.toAccountId(using: .substrate(SubstrateConstants.genericAddressPrefix)) else {
            return nil
        }

        return SubtensorValidatorDirectoryItem(
            hotkey: accountId,
            netuid: netuid,
            name: name,
            take: nil,
            reportedStake: stake,
            status: nil
        )
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
}
