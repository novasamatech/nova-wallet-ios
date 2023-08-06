import XCTest
@testable import novawallet
import BigInt

final class StakingRecommendationTests: XCTestCase {
    class RecommendationDelegate: RelaychainStakingRecommendationDelegate {
        let closure: (Result<RelaychainStakingRecommendation, Error>) -> Void
        
        var result: Result<RelaychainStakingRecommendation, Error>?
        
        init(closure: @escaping (Result<RelaychainStakingRecommendation, Error>) -> Void) {
            self.closure = closure
        }
        
        func didReceive(recommendation: RelaychainStakingRecommendation, amount: BigUInt) {
            let value: Result<RelaychainStakingRecommendation, Error> = .success(recommendation)
            result = value
            closure(value)
        }
        
        func didReceiveRecommendation(error: Error) {
            let value: Result<RelaychainStakingRecommendation, Error> = .failure(error)
            result = value
            closure(value)
        }
    }
    

    func testPolkadotHybridRecommendationExpectingDirect() throws {
        if let recommendation = try performHybridRecommendationTest(
            for: KnowChainId.polkadot,
            amount: 460
        ) {
            Logger.shared.info("Recommendation: \(recommendation)")
        } else {
            XCTFail("No recommendation")
        }
    }

    func performHybridRecommendationTest(
        for chainId: ChainModel.Id,
        amount: Decimal
    ) throws -> RelaychainStakingRecommendation? {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        
        guard let chain = chainRegistry.getChain(for: chainId), let asset = chain.utilityAsset() else {
            throw ChainRegistryError.noChain(chainId)
        }
        
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let optStaking = chainAsset.asset.stakings?.sorted { staking1, staking2 in
            staking1.isMorePreferred(than: staking2)
        }.first
        
        guard
            let stakingType = optStaking,
            let consensus = ConsensusType(stakingType: stakingType),
            let amount = amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) else {
            throw CommonError.dataCorruption
        }
        
        let operationQueue = OperationQueue()
        
        let state = try StakingSharedStateFactory(
            storageFacade: storageFacade,
            chainRegistry: chainRegistry,
            eventCenter: EventCenter.shared,
            syncOperationQueue: operationQueue,
            repositoryOperationQueue: operationQueue,
            logger: Logger.shared
        ).createStartRelaychainStaking(for: chainAsset, consensus: consensus)
        
        let recommedationMediatorFactory = StakingRecommendationMediatorFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        
        guard let recommendationMediator = recommedationMediatorFactory.createHybridStakingMediator(for: state) else {
            throw CommonError.dataCorruption
        }
        
        let expectation = XCTestExpectation()
        
        let delegateMock = RecommendationDelegate { _ in
            expectation.fulfill()
        }
        
        recommendationMediator.delegate = delegateMock
        recommendationMediator.startRecommending()
        recommendationMediator.update(amount: amount)
        
        wait(for: [expectation], timeout: 600)
        
        switch delegateMock.result {
        case let .success(recommendation):
            return recommendation
        case let .failure(error):
            Logger.shared.error("Receive error: \(error)")
            return nil
        case .none:
            return nil
        }
    }
}
