import Foundation

extension SubtensorValidatorDirectoryService {
    struct Row {
        let hotkey: AccountId
        let name: String?
        let stake: BigRational?
    }

    struct ListingReceipt: Equatable {
        let requestId: String?
        let receivedAt: TimeInterval

        init(response: BittensorApiResult<BittensorApi.ValidatorCollection>) {
            requestId = response.requestId
            receivedAt = response.receivedAt
        }
    }

    struct Listing {
        let rows: [Row]
        let listStamp: SubtensorBackendStamp?
        let isPartial: Bool
        let receipt: ListingReceipt
    }

    struct Enrichment {
        let snapshot: SubtensorValidatorChainSnapshot
        let enrichedPairs: Set<SubtensorHotkeySubnet>
    }

    static func makeListing(
        from response: BittensorApiResult<BittensorApi.ValidatorCollection>,
        netuid: UInt16,
        logger: LoggerProtocol
    ) throws -> Listing {
        let collection = response.value
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
            let stake = reportedStake(item.reportedMeasurements.validatorStake)
            rows.append(Row(hotkey: hotkey, name: name, stake: stake))
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
            isPartial: collection.meta.completeness == .partial,
            receipt: ListingReceipt(response: response)
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

    static func enrichmentQuery(rows: [Row], netuid: UInt16) -> SubtensorValidatorChainQuery {
        let pairs = rows.prefix(enrichmentRowLimit).map { SubtensorHotkeySubnet(hotkey: $0.hotkey, netuid: netuid) }

        return SubtensorValidatorChainQuery(pairs: pairs, includesHotkeyAlpha: true)
    }

    static func takeFraction(_ take: UInt16) -> Decimal {
        Decimal(take) / Decimal(SubtensorStakingPallet.perU16Denominator)
    }

    static func makeItem(
        hotkey: AccountId,
        name: String?,
        stake: BigRational?,
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
            reportedStake: stake,
            status: isEnriched ? SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair) : nil
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
                makeItem(
                    hotkey: row.hotkey,
                    name: row.name,
                    stake: row.stake,
                    netuid: subnet.netuid,
                    enrichment: enrichment
                )
            },
            listStamp: listing.listStamp,
            isPartial: listing.isPartial,
            isEnrichmentTruncated: listing.rows.count > enrichmentRowLimit,
            chainBlock: enrichment.snapshot.blockNumber
        )
    }
}
