import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorSubnetDetailsViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testThreeSaferFactorsGiveTheSaferHeading() {
        let factors = makeFactory().createFactors(for: makeState(poolTao: 30000), locale: locale)

        XCTAssertEqual(factors.heading, "WHY THIS IS SAFER")
        XCTAssertEqual(factors.footer, "3 of 5 factors on the safer side · this is not a guarantee")
    }

    func testTwoSaferFactorsGiveTheRiskierHeading() {
        let factors = makeFactory().createFactors(for: makeState(poolTao: 8400), locale: locale)

        XCTAssertEqual(factors.heading, "WHY THIS IS RISKIER")
        XCTAssertEqual(factors.footer, "2 of 5 factors on the safer side · this is not a guarantee")
    }

    private func makeFactory() -> SubtensorSubnetDetailsViewModelFactory {
        SubtensorSubnetDetailsViewModelFactory(
            subnet: makeSubnet(),
            chainAsset: makeChainAsset(),
            currency: .usd,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
    }

    private func makeState(poolTao: Decimal) -> SubtensorSubnetDetailsState {
        SubtensorSubnetDetailsState(
            isFiat: false,
            period: .week,
            history: .loading,
            listing: .notListed,
            isRankingLoaded: true,
            rankingView: makeRankingView(poolTao: poolTao),
            validator: .unselected,
            isYieldsLoaded: true,
            yields: nil,
            amount: .fixed(5),
            transferable: nil,
            taoPrice: nil,
            isFavorite: false,
            now: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }

    private func makeRankingView(poolTao: Decimal) -> SubtensorRankedSubnets {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        let generation = SubtensorRecommendationGeneration(
            id: "generation",
            sourceBlockNumber: 6_000_000,
            modelVersion: "5.0",
            ageSeconds: 60,
            receivedAt: 0,
            isServedFromMemory: false,
            excludedNetuids: [],
            carriedOverNetuids: [],
            inputFlags: [],
            stamp: stamp,
            isPartial: false
        )

        let volatility = makeScore(raw: 0.052, normalized: 57)

        let rankedSubnet = SubtensorRankedSubnet(
            netuid: 64,
            subnetName: "Chutes",
            symbol: "ش",
            status: .scored,
            isEligible: true,
            reasons: [],
            riskClass: .balanced,
            subnetRisk: 41,
            breakdown: SubtensorSubnetBreakdown(
                volatility: volatility,
                maxDrawdown: makeScore(raw: 0.2, normalized: 22),
                poolDepth: makeScore(raw: poolTao, normalized: 10),
                age: makeScore(raw: 2_000_000, normalized: 30),
                emissionStability: makeScore(raw: 1, normalized: 0),
                stakeConcentration: makeScore(raw: 0.85, normalized: 28)
            ),
            taoIn: poolTao,
            priceTao: 0.0738,
            ageBlocks: 2_000_000,
            scoredValidators: 24,
            eligibleValidators: 20,
            flags: []
        )

        return SubtensorRankedSubnets(
            generation: generation,
            policy: SubtensorRecommendationPolicy(
                classification: .pair,
                requiresIdentity: true,
                requiresPositiveSignal: false,
                insufficientHistory: .neutral
            ),
            items: [rankedSubnet]
        )
    }

    private func makeScore(raw: Decimal, normalized: Decimal) -> SubtensorMetricScore {
        SubtensorMetricScore(raw: raw, normalized: normalized, weight: 0.2, isDerived: false, flags: [])
    }

    private func makeSubnet() -> SubtensorCatalogueSubnet {
        let stamp = SubtensorBackendStamp(asOf: Date(timeIntervalSince1970: 1_790_000_000), freshness: .fresh)

        return SubtensorCatalogueSubnet(
            netuid: 64,
            name: "Chutes",
            symbol: "ش",
            networkRegisteredAt: 4_531_295,
            tempo: 360,
            ownerColdkey: "",
            ownerHotkey: "",
            links: SubtensorSubnetLinks(
                githubRepo: "",
                subnetContact: "",
                subnetUrl: "",
                subnetWebsite: "",
                discord: "",
                additional: ""
            ),
            taoReserve: 210_000_000_000_000,
            alphaReserve: 2_845_000_000_000_000,
            alphaOutstanding: 3_100_000_000_000_000,
            taoPerAlpha: 73_800_000,
            metadataStamp: stamp,
            pricesStamp: stamp
        )
    }

    private func makeChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }
}
