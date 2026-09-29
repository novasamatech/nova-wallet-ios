import XCTest
@testable import novawallet
import BigInt

final class BittensorLocalBannerTests: XCTestCase {
    func testAssetWithoutSubtensorStakingHidesTheBanner() {
        let chain = createBittensorChain(stakings: nil)

        XCTAssertNil(BittensorLocalBanner.chainAsset(for: chain))
    }

    func testAssetWithSubtensorStakingShowsTheBanner() {
        let chain = createBittensorChain(stakings: [.subtensor])

        XCTAssertEqual(
            BittensorLocalBanner.chainAsset(for: chain)?.chainAssetId,
            ChainAssetId(chainId: KnowChainId.bittensor, assetId: AssetModel.utilityAssetId)
        )
    }

    func testEntryDisabledHidesTheBanner() {
        let banner = BittensorLocalBanner.resolve(
            connectedChain: createBittensorChain(stakings: [.subtensor]),
            config: createConfig(entryEnabled: false),
            hasAccount: true,
            balance: .success(createBalance(free: 1_000_000_000)),
            closedBanners: ClosedBanners()
        )

        XCTAssertNil(banner)
    }

    func testWalletWithoutFreeTaoGetsTheGetTaoVariant() {
        let banner = BittensorLocalBanner.resolve(
            connectedChain: createBittensorChain(stakings: [.subtensor]),
            config: createConfig(entryEnabled: true),
            hasAccount: true,
            balance: .success(nil),
            closedBanners: ClosedBanners()
        )

        XCTAssertEqual(banner?.variant, .getTao)
    }

    func testWalletWithTaoGetsTheEarnVariantWithTheConfigHeadline() {
        let banner = BittensorLocalBanner.resolve(
            connectedChain: createBittensorChain(stakings: [.subtensor]),
            config: createConfig(entryEnabled: true),
            hasAccount: true,
            balance: .success(createBalance(free: 1_000_000_000)),
            closedBanners: ClosedBanners()
        )

        XCTAssertEqual(banner?.variant, .earn(headline: Decimal(string: "0.4")))
    }

    func testWalletWithoutBittensorAccountGetsTheEarnVariant() {
        let banner = BittensorLocalBanner.resolve(
            connectedChain: createBittensorChain(stakings: [.subtensor]),
            config: createConfig(entryEnabled: true),
            hasAccount: false,
            balance: nil,
            closedBanners: ClosedBanners()
        )

        XCTAssertEqual(banner?.variant, .earn(headline: Decimal(string: "0.4")))
    }

    func testAssetWithoutSubtensorStakingHidesTheEarnAction() {
        let chain = createBittensorChain(stakings: nil)
        let chainAsset = ChainAsset(chain: chain, asset: chain.utilityAsset()!)

        XCTAssertFalse(
            BittensorLocalBanner.isEarnActionAvailable(on: chainAsset, config: createConfig(entryEnabled: true))
        )
    }

    func testAssetWithSubtensorStakingShowsTheEarnAction() {
        let chain = createBittensorChain(stakings: [.subtensor])
        let chainAsset = ChainAsset(chain: chain, asset: chain.utilityAsset()!)

        XCTAssertTrue(
            BittensorLocalBanner.isEarnActionAvailable(on: chainAsset, config: createConfig(entryEnabled: true))
        )
    }

    private func createBittensorChain(stakings: [StakingType]?) -> ChainModel {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: stakings,
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        return ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )
    }

    private func createConfig(entryEnabled: Bool) -> SubtensorEarnConfig {
        SubtensorEarnConfig(
            version: 1,
            entry: .init(enabled: entryEnabled, newBadgeUntil: nil),
            headlineMaxAnnualRate: Decimal(string: "0.40"),
            preferredRootValidator: nil,
            logoBaseUrl: nil,
            subnets: [:],
            invalidEntries: []
        )
    }

    private func createBalance(free: BigUInt) -> AssetBalance {
        AssetBalance(
            chainAssetId: ChainAssetId(chainId: KnowChainId.bittensor, assetId: AssetModel.utilityAssetId),
            accountId: AccountId.zeroAccountId(of: 32),
            freeInPlank: free,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )
    }
}
