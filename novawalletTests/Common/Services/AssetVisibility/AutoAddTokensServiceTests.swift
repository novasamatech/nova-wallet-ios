import BigInt
@testable import novawallet
import Operation_iOS
import XCTest

final class AutoAddTokensServiceTests: XCTestCase {
    func testPositiveBalanceIsDiscoveredForSelectedWalletUsingDefaultAutoAddSetting() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let accountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
        let chainAssetId = try XCTUnwrap(chain.utilityChainAssetId())
        let writer = RecordingAssetVisibilityWriter()
        let service = makeService(wallet: wallet, chain: chain, writer: writer)

        service.handleMetaAccountSettings(result: .success([]), metaId: wallet.metaId)

        // when

        service.handleAllBalances(
            result: .success([
                .insert(newItem: makeBalance(chainAssetId: chainAssetId, accountId: accountId, amount: 1))
            ])
        )

        // then

        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, wallet.metaId)
        XCTAssertEqual(application.ids, [chainAssetId])

        guard case let .passivePositiveBalance(autoAddEnabled) = application.event else {
            return XCTFail("Expected passive positive balance discovery")
        }

        XCTAssertTrue(autoAddEnabled)
    }

    func testAutoAddSettingIsScopedToCurrentlySelectedWallet() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let firstWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let selectedWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let accountId = try XCTUnwrap(selectedWallet.fetch(for: chain.accountRequest())?.accountId)
        let chainAssetId = try XCTUnwrap(chain.utilityChainAssetId())
        let writer = RecordingAssetVisibilityWriter()
        let service = makeService(wallet: selectedWallet, chain: chain, writer: writer)

        service.handleMetaAccountSettings(
            result: .success([
                .insert(
                    newItem: MetaAccountSettingsLocal(
                        metaId: firstWallet.metaId,
                        autoAddTokensWithBalance: true
                    )
                )
            ]),
            metaId: firstWallet.metaId
        )
        service.handleMetaAccountSettings(
            result: .success([
                .insert(
                    newItem: MetaAccountSettingsLocal(
                        metaId: selectedWallet.metaId,
                        autoAddTokensWithBalance: false
                    )
                )
            ]),
            metaId: selectedWallet.metaId
        )

        // when

        service.handleAllBalances(
            result: .success([
                .insert(newItem: makeBalance(chainAssetId: chainAssetId, accountId: accountId, amount: 1))
            ])
        )

        // then

        let application = try XCTUnwrap(writer.applications.last)
        XCTAssertEqual(application.metaId, selectedWallet.metaId)

        guard case let .passivePositiveBalance(autoAddEnabled) = application.event else {
            return XCTFail("Expected passive positive balance discovery")
        }

        XCTAssertFalse(autoAddEnabled)
    }
}

private extension AutoAddTokensServiceTests {
    func makeService(
        wallet: MetaAccountModel,
        chain: ChainModel,
        writer: AssetVisibilityWriting
    ) -> AutoAddTokensService {
        AutoAddTokensService(
            selectedMetaAccount: wallet,
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [chain]),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryStub(),
            assetVisibilitySubscriptionFactory: AssetVisibilitySubscriptionFactoryStub(),
            visibilityWriter: writer,
            defaultAssetsProvider: DefaultAssetsProviderStub(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    func makeBalance(
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        amount: BigUInt
    ) -> AssetBalance {
        AssetBalance(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: amount,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )
    }
}

private struct AssetVisibilitySubscriptionFactoryStub: AssetVisibilityLocalSubscriptionFactoryProtocol {
    func getVisibilityProvider(for _: MetaAccountModel.Id) -> StreamableProvider<AssetVisibilityLocal> {
        fatalError("Unused in this test")
    }

    func getSettingsProvider(for _: MetaAccountModel.Id) -> StreamableProvider<MetaAccountSettingsLocal> {
        fatalError("Unused in this test")
    }
}

private final class RecordingAssetVisibilityWriter: AssetVisibilityWriting {
    struct Application {
        let event: AssetVisibilityEvent
        let metaId: MetaAccountModel.Id
        let ids: Set<ChainAssetId>
    }

    private(set) var applications: [Application] = []

    func apply(
        event: AssetVisibilityEvent,
        metaId: MetaAccountModel.Id,
        ids: Set<ChainAssetId>,
        runningCallbackIn _: DispatchQueue?,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        applications.append(Application(event: event, metaId: metaId, ids: ids))
        completion?(.success(()))
    }
}

private struct DefaultAssetsProviderStub: DefaultAssetsProviding {
    func createDefaultAssetsWrapper() -> CompoundOperationWrapper<DefaultAssetsList> {
        CompoundOperationWrapper.createWithResult(.empty)
    }
}
