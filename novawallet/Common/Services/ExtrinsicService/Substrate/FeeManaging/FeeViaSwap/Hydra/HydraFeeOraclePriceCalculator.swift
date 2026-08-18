import Foundation
import BigInt

enum HydraFeeOraclePriceCalculator {
    struct OracleLeg: Hashable {
        let source: Data
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId

        var isInverted: Bool {
            assetIn > assetOut
        }

        var lower: HydraDx.AssetId {
            min(assetIn, assetOut)
        }

        var higher: HydraDx.AssetId {
            max(assetIn, assetOut)
        }

        func key(for period: HydraEmaOracle.Period) -> HydraEmaOracle.OracleKey {
            .init(source: source, lowerAsset: lower, higherAsset: higher, period: period)
        }
    }

    static func resolveRoute(
        stored: [HydraRouter.Trade]?,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId
    ) -> [HydraRouter.Trade] {
        guard let stored, !stored.isEmpty else {
            return [HydraRouter.Trade(pool: .omnipool, assetIn: assetIn, assetOut: assetOut)]
        }

        guard assetIn > assetOut else {
            return stored
        }

        return Array(
            stored
                .map { HydraRouter.Trade(pool: $0.pool, assetIn: $0.assetOut, assetOut: $0.assetIn) }
                .reversed()
        )
    }

    static func oracleLegs(
        for route: [HydraRouter.Trade],
        hubAssetId: HydraDx.AssetId
    ) -> [OracleLeg]? {
        var legs: [OracleLeg] = []

        for hop in route {
            switch hop.pool {
            case .omnipool:
                legs += compose(hop: hop, via: hubAssetId, source: HydraEmaOracle.Source.omnipool)
            case let .stableswap(poolId):
                legs += compose(hop: hop, via: poolId, source: HydraEmaOracle.Source.stableswap)
            case .xyk:
                legs += makeLeg(
                    source: HydraEmaOracle.Source.xyk,
                    assetIn: hop.assetIn,
                    assetOut: hop.assetOut
                )
            case .aave:
                break
            case .lbp, .hsm:
                return nil
            }
        }

        return legs
    }

    static func fastForwardedPrice(
        tenMinutes: HydraEmaOracle.Entry,
        lastBlock: HydraEmaOracle.Entry,
        parentBlock: BlockNumber
    ) -> BigRational {
        let previous = tenMinutes.price.asBigRational
        let incoming = lastBlock.price.asBigRational

        guard parentBlock > tenMinutes.updatedAt else {
            return previous
        }

        let staleBlocks = parentBlock - tenMinutes.updatedAt
        let complement = HydraEmaOracle.Smoothing.complementPow(staleBlocks: staleBlocks)

        guard complement > 0 else {
            return incoming
        }

        let one = HydraFraction.one

        return BigRational(
            numerator: previous.numerator * incoming.denominator * complement
                + incoming.numerator * previous.denominator * (one - complement),
            denominator: previous.denominator * incoming.denominator * one
        )
    }

    static func routePrice(
        legs: [OracleLeg],
        entries: [HydraEmaOracle.OracleKey: HydraEmaOracle.Entry],
        parentBlock: BlockNumber
    ) -> HydraFeeConversion.Price? {
        var product = BigRational(numerator: 1, denominator: 1)

        for leg in legs {
            guard
                let tenMinutes = entries[leg.key(for: .tenMinutes)],
                let lastBlock = entries[leg.key(for: .lastBlock)] else {
                return nil
            }

            let price = fastForwardedPrice(
                tenMinutes: tenMinutes,
                lastBlock: lastBlock,
                parentBlock: parentBlock
            )

            product = product.mul(leg.isInverted ? price.inverted : price)
        }

        guard let inner = product.toFixedU128Inner() else {
            return nil
        }

        return HydraFeeConversion.Price(inner: inner)
    }
}

private extension HydraFeeOraclePriceCalculator {
    static func makeLeg(
        source: Data,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId
    ) -> [OracleLeg] {
        guard assetIn != assetOut else {
            return []
        }

        return [OracleLeg(source: source, assetIn: assetIn, assetOut: assetOut)]
    }

    static func compose(
        hop: HydraRouter.Trade,
        via intermediate: HydraDx.AssetId,
        source: Data
    ) -> [OracleLeg] {
        makeLeg(source: source, assetIn: hop.assetIn, assetOut: intermediate)
            + makeLeg(source: source, assetIn: intermediate, assetOut: hop.assetOut)
    }
}
