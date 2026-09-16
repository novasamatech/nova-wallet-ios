import BigInt
@testable import novawallet
import Operation_iOS
import XCTest

final class AutoAddTokensServiceTests: XCTestCase {
    func testPositiveExternalBalanceIsDiscoveredForSelectedWalletWithoutOrdinaryBalance() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let accountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
        let chainAssetId = try XCTUnwrap(chain.utilityChainAssetId())
        let writer = RecordingAssetVisibilityWriter()
        let service = makeService(wallet: wallet, chain: chain, writer: writer)

        service.handleMetaAccountSettings(result: .success([]), metaId: wallet.metaId)

        // when

        service.handleAllExternalAssetBalances(
            result: .success([
                .insert(newItem: makeExternalBalance(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    amount: 1
                ))
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

    func testExternalBalanceFromDifferentWalletIsIgnored() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let selectedWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let differentWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let differentAccountId = try XCTUnwrap(
            differentWallet.fetch(for: chain.accountRequest())?.accountId
        )
        let chainAssetId = try XCTUnwrap(chain.utilityChainAssetId())
        let writer = RecordingAssetVisibilityWriter()
        let service = makeService(wallet: selectedWallet, chain: chain, writer: writer)

        // when

        service.handleAllExternalAssetBalances(
            result: .success([
                .insert(newItem: makeExternalBalance(
                    chainAssetId: chainAssetId,
                    accountId: differentAccountId,
                    amount: 1
                ))
            ])
        )

        // then

        XCTAssertTrue(writer.applications.isEmpty)
    }

    func testOrdinaryAndExternalPositiveBalancesAreUnionedWithoutDuplicateDiscovery() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 0)
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let accountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
        let ordinaryChainAssetId = try XCTUnwrap(chain.utilityChainAssetId())
        let externalAsset = try XCTUnwrap(chain.assets.first { $0.assetId != ordinaryChainAssetId.assetId })
        let externalChainAssetId = ChainAssetId(chainId: chain.chainId, assetId: externalAsset.assetId)
        let writer = RecordingAssetVisibilityWriter()
        let service = makeService(wallet: wallet, chain: chain, writer: writer)

        // when

        service.handleAllBalances(
            result: .success([
                .insert(newItem: makeBalance(
                    chainAssetId: ordinaryChainAssetId,
                    accountId: accountId,
                    amount: 1
                ))
            ])
        )
        service.handleAllExternalAssetBalances(
            result: .success([
                .insert(newItem: makeExternalBalance(
                    identifier: "ordinary-external-balance",
                    chainAssetId: ordinaryChainAssetId,
                    accountId: accountId,
                    amount: 1
                )),
                .insert(newItem: makeExternalBalance(
                    identifier: "external-only-balance",
                    chainAssetId: externalChainAssetId,
                    accountId: accountId,
                    amount: 1
                ))
            ])
        )

        // then

        XCTAssertEqual(writer.applications.count, 2)
        XCTAssertEqual(
            writer.applications.last?.ids,
            [ordinaryChainAssetId, externalChainAssetId]
        )
    }

    func testZeroOrDeletedExternalBalanceDoesNotEmitPositiveCandidateAgain() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let accountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
        let chainAssetId = try XCTUnwrap(chain.utilityChainAssetId())
        let writer = RecordingAssetVisibilityWriter()
        let service = makeService(wallet: wallet, chain: chain, writer: writer)
        let identifier = "external-balance"

        service.handleMetaAccountSettings(result: .success([]), metaId: wallet.metaId)
        service.handleAllExternalAssetBalances(
            result: .success([
                .insert(newItem: makeExternalBalance(
                    identifier: identifier,
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    amount: 1
                ))
            ])
        )

        // when

        service.handleAllExternalAssetBalances(
            result: .success([
                .update(newItem: makeExternalBalance(
                    identifier: identifier,
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    amount: 0
                ))
            ])
        )

        // then

        XCTAssertEqual(writer.applications.count, 2)
        XCTAssertEqual(writer.applications[0].ids, [chainAssetId])
        XCTAssertTrue(writer.applications[1].ids.isEmpty)

        guard case let .passivePositiveBalance(autoAddEnabled) = writer.applications[1].event else {
            return XCTFail("Expected passive positive balance discovery")
        }

        XCTAssertTrue(autoAddEnabled)

        // when

        service.handleAllExternalAssetBalances(
            result: .success([
                .delete(deletedIdentifier: identifier)
            ])
        )

        // then

        XCTAssertEqual(writer.applications.count, 2)
    }

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
            externalBalancesSubscriptionFactory: ExternalBalanceSubscriptionFactoryStub(),
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

    func makeExternalBalance(
        identifier: String = UUID().uuidString,
        chainAssetId: ChainAssetId,
        accountId: AccountId,
        amount: BigUInt
    ) -> ExternalAssetBalance {
        ExternalAssetBalance(
            identifier: identifier,
            chainAssetId: chainAssetId,
            accountId: accountId,
            amount: amount,
            type: .nominationPools,
            subtype: nil,
            param: nil
        )
    }
}

private struct ExternalBalanceSubscriptionFactoryStub: ExternalBalanceLocalSubscriptionFactoryProtocol {
    func getExternalAssetBalanceProvider(
        for _: AccountId,
        chainAsset _: ChainAsset
    ) -> StreamableProvider<ExternalAssetBalance>? {
        nil
    }

    func getAllExternalAssetBalanceProvider() -> StreamableProvider<ExternalAssetBalance>? {
        nil
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
