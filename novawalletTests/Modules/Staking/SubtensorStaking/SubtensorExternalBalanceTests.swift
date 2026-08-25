import XCTest
@testable import novawallet
import BigInt
import Operation_iOS

final class SubtensorExternalBalanceTests: XCTestCase {
    let subtensorChainId = KnowChainId.bittensor

    func testSubtensorStakingRawTypeDecodes() {
        XCTAssertEqual(ExternalAssetBalance.BalanceType(rawType: "subtensorStaking"), .subtensorStaking)
    }

    func testUnknownRawTypeDegrades() {
        XCTAssertEqual(ExternalAssetBalance.BalanceType(rawType: "subtensor-whatever"), .unknown)
    }

    func testSubtensorStakingLockTitleIsStaked() {
        let title = ExternalAssetBalance.BalanceType.subtensorStaking.lockTitle.value(
            for: Locale(identifier: "en")
        )

        XCTAssertEqual(title, "Staked")
    }

    func testSavedBalanceReadsBackAsSubtensorStakingType() throws {
        let storageFacade = SubstrateStorageTestFacade()

        let balance = SubtensorStakedBalance(
            chainAssetId: ChainAssetId(chainId: subtensorChainId, assetId: 0),
            accountId: Data(repeating: 1, count: 32),
            amount: 57_816_438
        )

        let writeRepository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(SubtensorStakedBalanceMapper())
        )

        let saveOperation = writeRepository.saveOperation({ [balance] }, { [] })
        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)
        _ = try saveOperation.extractNoCancellableResultData()

        let readRepository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(ExternalAssetBalanceMapper())
        )

        let fetchOperation = readRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let balances = try fetchOperation.extractNoCancellableResultData()

        XCTAssertEqual(balances.count, 1)
        XCTAssertEqual(balances.first?.type, .subtensorStaking)
        XCTAssertEqual(balances.first?.amount, BigUInt(57_816_438))
        XCTAssertEqual(balances.first?.accountId, balance.accountId)
        XCTAssertNil(balances.first?.param)
        XCTAssertNil(balances.first?.subtype)
    }

    func testSavedBalanceRoundTripsThroughSubtensorMapper() throws {
        let storageFacade = SubstrateStorageTestFacade()

        let balance = SubtensorStakedBalance(
            chainAssetId: ChainAssetId(chainId: subtensorChainId, assetId: 0),
            accountId: Data(repeating: 1, count: 32),
            amount: 57_816_438
        )

        let repository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(SubtensorStakedBalanceMapper())
        )

        let saveOperation = repository.saveOperation({ [balance] }, { [] })
        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)
        _ = try saveOperation.extractNoCancellableResultData()

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let balances = try fetchOperation.extractNoCancellableResultData()

        XCTAssertEqual(balances, [balance])
    }
}
