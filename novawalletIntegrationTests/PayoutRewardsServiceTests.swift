import XCTest
import Keystore_iOS
import SubstrateSdk
import NovaCrypto
import Operation_iOS
@testable import novawallet

class PayoutRewardsServiceTests: XCTestCase {
    func testPayoutsForAzero() throws {
        let selectedAccount = "5HKcmzDLApS5xERzruR6qwiLWjeVyg1RVQmFNoM44Gtni7SX"
        let chainId = KnowChainId.alephZero

        do {
            let payouts = try fetchNominatorPayout(for: selectedAccount, chainId: chainId)
            Logger.shared.info("Payouts: \(payouts)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendNominator() throws {
        let selectedAccount = "5HKPqdbQGZePdoFKzcjXXHEbFhfGCjFpmGDmcBLnGMXSKAnN"
        let chainId = KnowChainId.westend

        do {
            let payouts = try fetchNominatorPayout(for: selectedAccount, chainId: chainId)
            Logger.shared.info("Payouts: \(payouts)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendValidator() throws {
        let selectedAccount = "5CFPcUJgYgWryPaV1aYjSbTpbTLu42V32Ytw1L9rfoMAsfGh"
        let chainId = KnowChainId.westend

        do {
            let payouts = try fetchValidatorPayout(for: selectedAccount, chainId: chainId)
            Logger.shared.info("Payouts: \(payouts)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPolkadotNominator() throws {
        let selectedAccount = "16ZL8yLyXv3V3L3z9ofR1ovFLziyXaN1DPq4yffMAZ9czzBD"
        let chainId = KnowChainId.polkadot

        do {
            let payouts = try fetchNominatorPayout(for: selectedAccount, chainId: chainId)
            Logger.shared.info("Payouts: \(payouts)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func fetchNominatorPayout(for selectedAccount: AccountAddress, chainId: ChainModel.Id) throws -> PayoutsInfo {
        let operationQueue = OperationQueue()
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let chainAsset = chain.utilityChainAsset(),
            let rewardUrl = chain.externalApis?.staking()?.first?.url else {
            throw ChainRegistryError.connectionUnavailable
        }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let validatorsResolutionFactory = PayoutValidatorsForNominatorFactory(
            url: rewardUrl
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let payoutInfoFactory = NominatorPayoutInfoFactory(chainAssetInfo: chainAsset.chainAssetInfo)

        let exposureSearchFactory = ExposurePagedEraOperationFactory(operationQueue: operationQueue)
        let unclaimedRewardsFacade = StakingUnclaimedRewardsFacade(
            requestFactory: storageRequestFactory,
            operationQueue: operationQueue
        )

        let exposureFacade = StakingValidatorExposureFacade(
            operationQueue: operationQueue,
            requestFactory: storageRequestFactory
        )

        let service = PayoutRewardsService(
            selectedAccountAddress: selectedAccount,
            chainFormat: chainAsset.chain.chainFormat,
            validatorsResolutionFactory: validatorsResolutionFactory,
            erasStakersPagedSearchFactory: exposureSearchFactory,
            exposureFactoryFacade: exposureFacade,
            unclaimedRewardsFacade: unclaimedRewardsFacade,
            runtimeCodingService: chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)!,
            storageRequestFactory: storageRequestFactory,
            engine: chainRegistry.getConnection(for: chainAsset.chain.chainId)!,
            operationManager: operationManager,
            identityProxyFactory: identityProxyFactory,
            payoutInfoFactory: payoutInfoFactory
        )

        let wrapper = service.fetchPayoutsOperationWrapper()

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func fetchValidatorPayout(for selectedAccount: AccountAddress, chainId: ChainModel.Id) throws -> PayoutsInfo {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let chainAsset = chain.utilityChainAsset() else {
            throw ChainRegistryError.connectionUnavailable
        }

        let operationQueue = OperationQueue()
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let validatorsResolutionFactory = PayoutValidatorsForValidatorFactory()

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let payoutInfoFactory = ValidatorPayoutInfoFactory(chainAssetInfo: chainAsset.chainAssetInfo)

        let exposureSearchFactory = ExposurePagedEraOperationFactory(operationQueue: operationQueue)
        let unclaimedRewardsFacade = StakingUnclaimedRewardsFacade(
            requestFactory: storageRequestFactory,
            operationQueue: operationQueue
        )

        let exposureFacade = StakingValidatorExposureFacade(
            operationQueue: operationQueue,
            requestFactory: storageRequestFactory
        )

        let service = PayoutRewardsService(
            selectedAccountAddress: selectedAccount,
            chainFormat: chainAsset.chain.chainFormat,
            validatorsResolutionFactory: validatorsResolutionFactory,
            erasStakersPagedSearchFactory: exposureSearchFactory,
            exposureFactoryFacade: exposureFacade,
            unclaimedRewardsFacade: unclaimedRewardsFacade,
            runtimeCodingService: chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)!,
            storageRequestFactory: storageRequestFactory,
            engine: chainRegistry.getConnection(for: chainAsset.chain.chainId)!,
            operationManager: operationManager,
            identityProxyFactory: identityProxyFactory,
            payoutInfoFactory: payoutInfoFactory
        )

        let wrapper = service.fetchPayoutsOperationWrapper()

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
