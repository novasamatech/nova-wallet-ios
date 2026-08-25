@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorHistoryFiltersProviderTests: XCTestCase {
    private func makeChainAsset(stakings: [StakingType]?) -> ChainAsset {
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
            enabled: true,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func fetchFilters(for chainAsset: ChainAsset) throws -> [TransactionHistoryLocalFilterProtocol] {
        let wrapper = SubtensorHistoryFiltersProvider(chainAsset: chainAsset).createFiltersWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func subnetAccountId(netuid: UInt16) -> AccountId {
        var accountId = SubtensorStakingPallet.subnetAccountPrefix!
        withUnsafeBytes(of: netuid.littleEndian) { accountId.append(contentsOf: $0) }
        accountId.append(Data(repeating: 0, count: 32 - accountId.count))
        return accountId
    }

    private func makeTransfer(
        for chainAsset: ChainAsset,
        sender: AccountId,
        receiver: AccountId,
        callPath: CallCodingPath = .transfer
    ) throws -> TransactionHistoryItem {
        let source = TransactionHistoryItemSource.substrate
        let hash = Data.random(of: 32)!.toHexWithPrefix()

        return try TransactionHistoryItem(
            identifier: TransactionHistoryItem.createIdentifier(from: hash, source: source),
            source: source,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId,
            sender: sender.toAddress(using: chainAsset.chain.chainFormat),
            receiver: receiver.toAddress(using: chainAsset.chain.chainFormat),
            amountInPlank: "1000000000",
            status: .success,
            txHash: hash,
            timestamp: 0,
            fee: nil,
            feeAssetId: nil,
            blockNumber: 100,
            txIndex: 0,
            callPath: callPath,
            call: nil,
            swap: nil
        )
    }

    func testProviderProducesNoFiltersForNonSubtensorAsset() throws {
        let filters = try fetchFilters(for: makeChainAsset(stakings: [.relaychain]))

        XCTAssertTrue(filters.isEmpty)
    }

    func testProviderProducesSubnetAccountPrefixFilterForSubtensorAsset() throws {
        let filters = try fetchFilters(for: makeChainAsset(stakings: [.subtensor]))

        XCTAssertEqual(filters.count, 1)
        XCTAssertTrue(filters.first is TransactionHistoryAccountPrefixFilter)
    }

    func testFilterSuppressesTransferToSubnetAccount() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try XCTUnwrap(fetchFilters(for: chainAsset).first)

        let stakeTransfer = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: subnetAccountId(netuid: 64)
        )

        XCTAssertFalse(filter.shouldDisplayOperation(model: stakeTransfer))
    }

    func testFilterSuppressesTransferFromSubnetAccount() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try XCTUnwrap(fetchFilters(for: chainAsset).first)

        let unstakeTransfer = try makeTransfer(
            for: chainAsset,
            sender: subnetAccountId(netuid: 0),
            receiver: Data(repeating: 0x11, count: 32)
        )

        XCTAssertFalse(filter.shouldDisplayOperation(model: unstakeTransfer))
    }

    func testFilterKeepsTransfersBetweenUserAccounts() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try XCTUnwrap(fetchFilters(for: chainAsset).first)

        let userTransfer = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: Data(repeating: 0x22, count: 32)
        )

        XCTAssertTrue(filter.shouldDisplayOperation(model: userTransfer))
    }

    func testFilterKeepsStakingExtrinsicRows() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try XCTUnwrap(fetchFilters(for: chainAsset).first)

        let stakingExtrinsic = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: subnetAccountId(netuid: 0),
            callPath: CallCodingPath(moduleName: "SubtensorModule", callName: "add_stake")
        )

        XCTAssertTrue(filter.shouldDisplayOperation(model: stakingExtrinsic))
    }
}
