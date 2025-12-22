import XCTest
@testable import novawallet
import BigInt

final class NominationPoolsSyncTests: XCTestCase {
    func testWalletWithPoolStaking() throws {
        try performTestForAddress("1SohJrC8gHwHeJT1nkSonEbMd6yrkJgw8PwGsXUrKw3YrEK", chainId: KnowChainId.polkadot)
    }

    private func performTestForAddress(_ address: AccountAddress, chainId: ChainModel.Id) throws {
        let accountId = try address.toAccountId()
        let chainAssetId = ChainAssetId(chainId: chainId, assetId: 0)

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "Test",
            substrateAccountId: accountId,
            substrateCryptoType: 0,
            substratePublicKey: Data(),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: .watchOnly,
            multisig: nil
        )

        try performSyncTest(for: wallet, chainAssetId: chainAssetId)
    }

    private func performSyncTest(for wallet: MetaAccountModel, chainAssetId: ChainAssetId) throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let chain = chainRegistry.getChain(for: chainAssetId.chainId),
            let asset = chain.asset(for: chainAssetId.assetId),
            let accountResponse = wallet.fetch(for: chain.accountRequest()),
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.noChain(chainAssetId.chainId)
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let multistakingRepositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)
        let substrateRepository = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let nominationPoolsMultistaking = PoolsMultistakingUpdateService(
            walletId: wallet.metaId,
            accountId: accountResponse.accountId,
            chainAsset: chainAsset,
            stakingType: .nominationPools,
            dashboardRepository: multistakingRepositoryFactory.createNominationPoolsRepository(),
            accountRepository: multistakingRepositoryFactory.createResolvedAccountRepository(),
            cacheRepository: substrateRepository.createChainStorageItemRepository(),
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: OperationQueue(),
            workingQueue: .global(qos: .background),
            logger: Logger.shared
        )

        nominationPoolsMultistaking.setup()

        let npoolsRemoteSubscriptionService = NominationPoolsRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: substrateRepository.createChainStorageItemRepository(),
            syncOperationManager: OperationManagerFacade.sharedManager,
            repositoryOperationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let globalSubscriptionId = npoolsRemoteSubscriptionService.attachToGlobalData(
            for: chain.chainId,
            queue: nil,
            closure: nil
        )

        let npoolsPoolSubscriptionService = NominationPoolsPoolSubscriptionService(
            chainRegistry: chainRegistry,
            repository: substrateRepository.createChainStorageItemRepository(),
            syncOperationManager: OperationManagerFacade.sharedManager,
            repositoryOperationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let npoolsProviderFactory = NPoolsLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let npoolsAccountUpdatingService = NominationPoolsAccountUpdatingService(
            accountId: accountResponse.accountId,
            chainAsset: chainAsset,
            connection: connection,
            runtimeService: runtimeService,
            cacheRepository: substrateRepository.createChainStorageItemRepository(),
            npoolsLocalSubscriptionFactory: npoolsProviderFactory,
            remoteSubscriptionService: npoolsPoolSubscriptionService,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        npoolsAccountUpdatingService.setup()

        // when

        let logger = Logger.shared

        let poolMemberExpectation = XCTestExpectation()

        var optPoolMember: NominationPools.PoolMember?
        let poolMemberProvider = try npoolsProviderFactory.getPoolMemberProvider(
            for: accountResponse.accountId,
            chainId: chain.chainId
        )

        poolMemberProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optValue: NominationPools.PoolMember? = changes.reduceToLastChange()?.item

                if let value = optValue {
                    logger.info("Pool member: \(value)")
                    optPoolMember = value
                    poolMemberExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        wait(for: [poolMemberExpectation], timeout: 600)

        guard let poolMember = optPoolMember else {
            throw CommonError.dataCorruption
        }

        let lastPoolIdExpectation = XCTestExpectation()
        let lastPoolIdProvider = try npoolsProviderFactory.getLastPoolIdProvider(for: chain.chainId)

        lastPoolIdProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optPoolId: NominationPools.PoolId? = changes.reduceToLastChange()?.item?.value

                if let poolId = optPoolId {
                    logger.info("Last pool id: \(poolId)")
                    lastPoolIdExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let minJoinBondExpectation = XCTestExpectation()
        let minJoinBondProvider = try npoolsProviderFactory.getMinJoinBondProvider(for: chain.chainId)

        minJoinBondProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optMinJoinBond: BigUInt? = changes.reduceToLastChange()?.item?.value

                if let minJoinBond = optMinJoinBond {
                    logger.info("Min join bond: \(minJoinBond)")
                    minJoinBondExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let maxPoolMembersExpectation = XCTestExpectation()
        let maxPoolMembersProvider = try npoolsProviderFactory.getMaxPoolMembers(
            for: chain.chainId,
            missingEntryStrategy: .emitError
        )

        maxPoolMembersProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optMaxPoolMembers: UInt32? = changes.reduceToLastChange()?.item?.value

                if let maxPoolMembers = optMaxPoolMembers {
                    logger.info("Max pool members: \(maxPoolMembers)")
                    maxPoolMembersExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let maxPoolMembersPerPoolExpectation = XCTestExpectation()
        let maxPoolMembersPerPoolProvider = try npoolsProviderFactory.getMaxMembersPerPool(
            for: chain.chainId,
            missingEntryStrategy: .emitError
        )

        maxPoolMembersPerPoolProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optMaxPoolMembers: UInt32? = changes.reduceToLastChange()?.item?.value

                logger.info("Max pool members per pool: \(String(describing: optMaxPoolMembers))")
                maxPoolMembersPerPoolExpectation.fulfill()
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let counterForPoolMembersExpectation = XCTestExpectation()
        let counterForPoolMembersProvider = try npoolsProviderFactory.getCounterForPoolMembers(
            for: chain.chainId,
            missingEntryStrategy: .emitError
        )

        counterForPoolMembersProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optCounterForMembers: UInt32? = changes.reduceToLastChange()?.item?.value

                if let counterForMembers = optCounterForMembers {
                    logger.info("Counter for pool members: \(counterForMembers)")
                    counterForPoolMembersExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let bondedPoolExpectation = XCTestExpectation()

        let bondedPoolProvider = try npoolsProviderFactory.getBondedPoolProvider(
            for: poolMember.poolId,
            chainId: chain.chainId
        )

        bondedPoolProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optValue: NominationPools.BondedPool? = changes.reduceToLastChange()?.item

                if let value = optValue {
                    logger.info("Bonded pool: \(value)")
                    bondedPoolExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let rewardPoolExpectation = XCTestExpectation()
        let rewardPoolProvider = try npoolsProviderFactory.getRewardPoolProvider(
            for: poolMember.poolId,
            chainId: chain.chainId
        )

        rewardPoolProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optValue: NominationPools.RewardPool? = changes.reduceToLastChange()?.item

                if let value = optValue {
                    logger.info("Reward pool: \(value)")
                    rewardPoolExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let subpoolsExpectation = XCTestExpectation()
        let subpoolsProvider = try npoolsProviderFactory.getSubPoolsProvider(
            for: poolMember.poolId,
            chainId: chain.chainId
        )

        subpoolsProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optValue: NominationPools.SubPools? = changes.reduceToLastChange()?.item

                if let value = optValue {
                    logger.info("Subpools: \(value)")
                    subpoolsExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let metadataExpectation = XCTestExpectation()

        let metadataProvider = try npoolsProviderFactory.getMetadataProvider(
            for: poolMember.poolId,
            chainId: chain.chainId
        )

        metadataProvider.addObserver(
            self,
            deliverOn: nil,
            executing: { changes in
                let optValue: Data? = changes.reduceToLastChange()?.item?.wrappedValue

                if let value = optValue {
                    logger.info("Metadata: \(String(describing: String(data: value, encoding: .utf8)))")
                    metadataExpectation.fulfill()
                }
            }, failing: { error in
                logger.error("Error: \(error)")
            },
            options: .init()
        )

        let expectations = [lastPoolIdExpectation, minJoinBondExpectation, bondedPoolExpectation, rewardPoolExpectation, subpoolsExpectation, metadataExpectation, maxPoolMembersExpectation, maxPoolMembersPerPoolExpectation,
                            counterForPoolMembersExpectation]

        wait(for: expectations, timeout: 6000)

        npoolsRemoteSubscriptionService.detachFromGlobalData(
            for: globalSubscriptionId!,
            chainId: chain.chainId,
            queue: nil,
            closure: nil
        )

        bondedPoolProvider.removeObserver(self)
        metadataProvider.removeObserver(self)
        rewardPoolProvider.removeObserver(self)
        subpoolsProvider.removeObserver(self)
        minJoinBondProvider.removeObserver(self)
        lastPoolIdProvider.removeObserver(self)
        poolMemberProvider.removeObserver(self)
        maxPoolMembersProvider.removeObserver(self)
        counterForPoolMembersProvider.removeObserver(self)
        maxPoolMembersPerPoolProvider.removeObserver(self)
    }
}
