import Foundation
import BigInt
import SubstrateSdk
import XCTest
@testable import novawallet

enum SubtensorFlowChainWorld {
    typealias World = BittensorApiFixtureWorld

    static let coldkey = Data(repeating: 0x5C, count: 32)
    static let novaFeeBeneficiary = Data(repeating: 0xBB, count: 32)
    static let transferable: Balance = 48_200_000_000
    static let stakeAmount: Balance = 5_000_000_000
    static let chutesLogo = "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/sn64-4531295.png"

    static let chutesBuyQuote = SubtensorQuote(
        args: SubtensorQuoteArgs(netuid: 64, direction: .stake(taoIn: 4_957_858_206)),
        sim: SubtensorStakingPallet.SimSwapResult(
            taoAmount: 4_957_858_206,
            alphaAmount: 90_150_000_000,
            taoFee: 2_496_518,
            alphaFee: 0,
            taoSlippage: 0,
            alphaSlippage: 0
        ),
        spotPrice: 54_961_234,
        feeRate: 33,
        capturedAt: Date(timeIntervalSince1970: 1_790_000_000)
    )

    static func chainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: "bittensor",
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

    static func placeholderNovaFeeBeneficiary() throws -> AccountId {
        try Data(hexString: "0xa4373d7b6d136b822d25106a993945f40b4cbfcbb2cfd5782888b5d938f82b1a")
    }

    static func hotkey(_ member: World.Member) throws -> AccountId {
        try World.validator(member).hotkey.toAccountId(using: .substrate(SubstrateConstants.genericAddressPrefix))
    }

    static func subnetsInfo(overridingPrices: [UInt16: Balance] = [:]) throws -> SubtensorSubnetsInfo {
        let root = dynamicInfo(
            netuid: World.rootNetuid,
            name: World.rootName,
            symbol: World.rootSymbol,
            registeredAt: 0,
            tempo: UInt16(World.rootTempo)
        )

        let subnets = World.subnets.map { subnet in
            dynamicInfo(
                netuid: subnet.netuid,
                name: subnet.name,
                symbol: subnet.symbol,
                registeredAt: subnet.registeredAt,
                tempo: UInt16(subnet.tempo)
            )
        }

        let prices = try World.subnets.reduce(into: [UInt16: Balance]()) { result, subnet in
            result[subnet.netuid] = try SubtensorFlowLiteral.rao(fromTao: subnet.taoPerAlpha)
        }

        return SubtensorSubnetsInfo(
            subnets: [root] + subnets,
            prices: prices.merging(overridingPrices) { $1 },
            subtokenEnabled: Set(([root] + subnets).map(\.netuid)),
            ownerCut: SubtensorStakingPallet.defaultSubnetOwnerCut
        )
    }

    static func dynamicInfo(
        netuid: UInt16,
        name: String,
        symbol: String,
        registeredAt: UInt64,
        tempo: UInt16
    ) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: UInt8(netuid % 255), count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data(name.utf8),
            tokenSymbol: Data(symbol.utf8),
            tempo: tempo,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: 0,
            taoIn: 0,
            alphaOutEmission: 0,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: registeredAt,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }
}

extension SubtensorFlowTestCase {
    func takeFraction(_ take: UInt16) -> Decimal {
        Decimal(take) / Decimal(SubtensorStakingPallet.perU16Denominator)
    }

    func identity(_ name: String) -> SubtensorValidatorIdentity {
        SubtensorValidatorIdentity(name: name, url: nil, githubRepo: nil, image: nil, discord: nil, description: nil)
    }

    func emberItem(name: String?) throws -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: try SubtensorFlowChainWorld.hotkey(.ember),
            netuid: 64,
            name: name,
            take: takeFraction(9830),
            hotkeyAlpha: 301_250_000_000_000,
            status: SubtensorValidatorChainStatus(uid: 212, hasPermit: true, blocksSinceUpdate: 48, isActive: true),
            isNovaPreferred: true
        )
    }

    func asterRoot(name: String?) throws -> SubtensorValidatorDirectoryItem {
        try rootItem(.aster, uid: 3, take: 11796, stake: 98_000_000_000_000, name: name, isNovaPreferred: true)
    }

    func rootItem(
        _ member: BittensorApiFixtureWorld.Member,
        uid: UInt16,
        take: UInt16,
        stake: Balance,
        name: String?,
        isNovaPreferred: Bool = false
    ) throws -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: try SubtensorFlowChainWorld.hotkey(member),
            netuid: SubtensorStakingPallet.rootNetuid,
            name: name,
            take: takeFraction(take),
            hotkeyAlpha: stake,
            status: SubtensorValidatorChainStatus(uid: uid, hasPermit: nil, blocksSinceUpdate: nil, isActive: nil),
            isNovaPreferred: isNovaPreferred
        )
    }
}
