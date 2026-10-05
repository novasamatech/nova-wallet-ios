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
    static let chutesLogo = "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/bittensor/subnets/sn64-d9871395.png"

    static let subnetLogosJSON = """
    {"subnets":[
    {"netuid":0,"name":null,"symbol":"Τ","logo":null},
    {"netuid":4,"name":"Targon","symbol":"δ","logo":null},
    {"netuid":64,"name":"Chutes","symbol":"ش","logo":"\(chutesLogo)"}
    ]}
    """

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

    static func coldkeyAccount() -> MetaChainAccountResponse {
        let chain = chainAsset().chain

        return MetaChainAccountResponse(
            metaId: "flow-wallet",
            substrateAccountId: coldkey,
            ethereumAccountId: nil,
            walletIdenticonData: nil,
            delegationId: nil,
            chainAccount: ChainAccountResponse(
                metaId: "flow-wallet",
                chainId: chain.chainId,
                accountId: coldkey,
                publicKey: coldkey,
                name: "Flow",
                cryptoType: .sr25519,
                addressPrefix: chain.addressPrefix,
                isEthereumBased: false,
                isChainAccount: false,
                type: .secrets
            )
        )
    }

    static func productionNovaFeeBeneficiary() throws -> AccountId {
        try Data(hexString: "0x5d11a510a9bef3fae089b0500483f53498b6c5e616ff0027e37c1f1e84bb1565")
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

    func fixtureRootYield() throws -> SubtensorReportedYield {
        SubtensorReportedYield(
            reportedRate: "13.8421",
            stamp: SubtensorBackendStamp(asOf: try date("2026-09-24T06:00:00Z"), freshness: .fresh)
        )
    }

    func emberItem(name: String?) throws -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: try SubtensorFlowChainWorld.hotkey(.ember),
            netuid: 64,
            name: name,
            take: takeFraction(9830),
            reportedStake: try listedStake(of: .ember, name: name),
            status: SubtensorValidatorChainStatus(uid: 212, hasPermit: true, blocksSinceUpdate: 48, isActive: true)
        )
    }

    func cinderItem(name: String?) throws -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: try SubtensorFlowChainWorld.hotkey(.cinder),
            netuid: 64,
            name: name,
            take: takeFraction(6553),
            reportedStake: try listedStake(of: .cinder, name: name),
            status: SubtensorValidatorChainStatus(uid: 138, hasPermit: true, blocksSinceUpdate: 30, isActive: true)
        )
    }

    func asterRoot(name: String?) throws -> SubtensorValidatorDirectoryItem {
        try rootItem(.aster, uid: 3, take: 11796, name: name)
    }

    func rootItem(
        _ member: BittensorApiFixtureWorld.Member,
        uid: UInt16,
        take: UInt16,
        name: String?
    ) throws -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: try SubtensorFlowChainWorld.hotkey(member),
            netuid: SubtensorStakingPallet.rootNetuid,
            name: name,
            take: takeFraction(take),
            reportedStake: try listedStake(of: member, name: name),
            status: SubtensorValidatorChainStatus(uid: uid, hasPermit: nil, blocksSinceUpdate: nil, isActive: nil)
        )
    }

    func listedStake(of member: BittensorApiFixtureWorld.Member, name: String?) throws -> BigRational? {
        guard name != nil else {
            return nil
        }

        let measurements = BittensorApiFixtureDocuments.measurements(member, hasMetagraph: true)

        return try (measurements["validatorStake"] as? String).map { try BittensorApiDecimal.fraction($0) }
    }
}
