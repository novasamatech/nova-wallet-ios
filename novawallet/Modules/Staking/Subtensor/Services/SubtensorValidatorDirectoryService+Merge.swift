import Foundation

extension SubtensorValidatorDirectoryService {
    struct Row {
        let hotkey: AccountId
        let name: String?
    }

    struct Listing {
        let rows: [Row]
        let listStamp: SubtensorBackendStamp?
        let isPartial: Bool
    }

    struct Enrichment {
        let snapshot: SubtensorValidatorChainSnapshot
        let enrichedPairs: Set<SubtensorHotkeySubnet>
        let gatedPreference: AccountId?
    }

    static func makeListing(
        from collection: BittensorApi.ValidatorCollection,
        netuid: UInt16,
        logger: LoggerProtocol
    ) throws -> Listing {
        var rows: [Row] = []

        let candidates: [BittensorApi.Validator]

        if netuid == SubtensorStakingPallet.rootNetuid {
            guard case .available = collection.meta.components.validatorMetagraph else {
                throw SubtensorValidatorDirectoryServiceError.rootMetagraphUnavailable
            }

            candidates = collection.items.filter { $0.metagraphUid != nil }
        } else {
            candidates = collection.items
        }

        for item in candidates where item.netuid == netuid {
            guard let hotkey = try? item.hotkey.toAccountId(
                using: .substrate(SubstrateConstants.genericAddressPrefix)
            ) else {
                continue
            }

            let name = nonBlank(item.identitySourceName) ?? nonBlank(item.stakeSourceName)
            rows.append(Row(hotkey: hotkey, name: name))
        }

        if rows.count < candidates.count {
            logger.warning("Dropped \(candidates.count - rows.count) validator rows of netuid \(netuid)")
        }

        let components = collection.meta.components

        let stamps = [
            components.validatorStakes,
            components.validatorMetagraph,
            components.validatorIdentities
        ].compactMap { SubtensorBackendStamp(metadata: $0) }

        return Listing(
            rows: rows,
            listStamp: SubtensorBackendStamp.aggregate(stamps),
            isPartial: collection.meta.completeness == .partial
        )
    }

    static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    static func preferredHotkey(in config: SubtensorEarnConfig, for subnet: SubtensorSubnetRef) -> AccountId? {
        guard subnet.netuid != SubtensorStakingPallet.rootNetuid else {
            return config.preferredRootValidator
        }

        return config.subnetEntry(for: subnet)?.preferredValidator
    }

    static func enrichmentQuery(
        rows: [Row],
        preferredHotkey: AccountId?,
        netuid: UInt16
    ) -> SubtensorValidatorChainQuery {
        var pairs = rows.prefix(enrichmentRowLimit).map { SubtensorHotkeySubnet(hotkey: $0.hotkey, netuid: netuid) }

        if let preferredHotkey {
            let preferredPair = SubtensorHotkeySubnet(hotkey: preferredHotkey, netuid: netuid)

            if !pairs.contains(preferredPair) {
                pairs.append(preferredPair)
            }
        }

        return SubtensorValidatorChainQuery(pairs: pairs, includesHotkeyAlpha: true)
    }

    static func failingGate(
        of pair: SubtensorHotkeySubnet,
        snapshot: SubtensorValidatorChainSnapshot,
        gates: SubtensorClientGates
    ) -> SubtensorRecommendationGate? {
        guard let status = SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair) else {
            return .noCurrentUid
        }

        let isSubnet = pair.netuid != SubtensorStakingPallet.rootNetuid

        if isSubnet, gates.requirePermit, status.hasPermit != true {
            return .noPermit
        }

        guard
            let take = snapshot.takes[pair.hotkey],
            !SubtensorTakeGate.exceedsMax(take: take, maxTake: gates.maxTake) else {
            return .takeAboveMax
        }

        if isSubnet, gates.requireActiveWithinCutoff, status.isActive != true {
            return .inactive
        }

        return nil
    }

    static func gatedPreference(
        _ preferredHotkey: AccountId?,
        netuid: UInt16,
        snapshot: SubtensorValidatorChainSnapshot,
        recommendationService: SubtensorRecommendationServiceProtocol,
        logger: LoggerProtocol
    ) -> AccountId? {
        guard let preferredHotkey else {
            return nil
        }

        let pair = SubtensorHotkeySubnet(hotkey: preferredHotkey, netuid: netuid)
        let gates = recommendationService.lastSeenClientGates() ?? .backendDefault

        if let gate = failingGate(of: pair, snapshot: snapshot, gates: gates) {
            logger.warning("Ignoring the Nova preferred validator of netuid \(netuid): \(gate)")

            return nil
        }

        return preferredHotkey
    }

    static func takeFraction(_ take: UInt16) -> Decimal {
        Decimal(take) / Decimal(SubtensorStakingPallet.perU16Denominator)
    }

    static func makeItem(
        hotkey: AccountId,
        name: String?,
        netuid: UInt16,
        enrichment: Enrichment
    ) -> SubtensorValidatorDirectoryItem {
        let pair = SubtensorHotkeySubnet(hotkey: hotkey, netuid: netuid)
        let snapshot = enrichment.snapshot
        let isEnriched = enrichment.enrichedPairs.contains(pair)

        return SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: name,
            take: isEnriched ? snapshot.takes[hotkey].map { takeFraction($0) } : nil,
            hotkeyAlpha: isEnriched ? snapshot.hotkeyAlpha[pair] : nil,
            status: isEnriched ? SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair) : nil,
            isNovaPreferred: isEnriched && enrichment.gatedPreference == hotkey
        )
    }

    static func makeDirectory(
        subnet: SubtensorSubnetRef,
        listing: Listing,
        enrichment: Enrichment
    ) -> SubtensorValidatorDirectory {
        SubtensorValidatorDirectory(
            subnet: subnet,
            items: listing.rows.map { row in
                makeItem(hotkey: row.hotkey, name: row.name, netuid: subnet.netuid, enrichment: enrichment)
            },
            listStamp: listing.listStamp,
            isPartial: listing.isPartial,
            isEnrichmentTruncated: listing.rows.count > enrichmentRowLimit,
            chainBlock: enrichment.snapshot.blockNumber
        )
    }
}
