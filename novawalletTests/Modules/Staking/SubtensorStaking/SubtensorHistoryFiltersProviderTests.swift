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
        let wrapper = SubtensorHistoryFiltersProvider(
            chainAsset: chainAsset,
            logger: Logger.shared
        ).createFiltersWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func makeHistoryFilter(for chainAsset: ChainAsset) throws -> TransactionHistoryLocalFilterProtocol {
        try TransactionHistoryAndPredicate(innerFilters: fetchFilters(for: chainAsset))
    }

    private func placeholderBeneficiary() throws -> AccountId {
        try Data(hexString: "0xa4373d7b6d136b822d25106a993945f40b4cbfcbb2cfd5782888b5d938f82b1a")
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
        callPath: CallCodingPath = .transfer,
        status: TransactionHistoryItem.Status = .success
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
            status: status,
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

    func testProviderProducesSubnetAccountAndNovaFeeFiltersForSubtensorAsset() throws {
        let filters = try fetchFilters(for: makeChainAsset(stakings: [.subtensor]))

        XCTAssertEqual(filters.count, 2)
        XCTAssertTrue(filters.first is TransactionHistoryAccountPrefixFilter)
        XCTAssertTrue(filters.last is TransactionHistoryTransfersFilter)
    }

    func testFilterSuppressesTransferToSubnetAccount() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try makeHistoryFilter(for: chainAsset)

        let stakeTransfer = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: subnetAccountId(netuid: 64)
        )

        XCTAssertFalse(filter.shouldDisplayOperation(model: stakeTransfer))
    }

    func testFilterSuppressesTransferFromSubnetAccount() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try makeHistoryFilter(for: chainAsset)

        let unstakeTransfer = try makeTransfer(
            for: chainAsset,
            sender: subnetAccountId(netuid: 0),
            receiver: Data(repeating: 0x11, count: 32)
        )

        XCTAssertFalse(filter.shouldDisplayOperation(model: unstakeTransfer))
    }

    func testSuccessfulTransferToPlaceholderBeneficiaryIsHidden() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try makeHistoryFilter(for: chainAsset)

        let novaFeeTransfer = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: placeholderBeneficiary(),
            callPath: .transferKeepAlive
        )

        XCTAssertFalse(filter.shouldDisplayOperation(model: novaFeeTransfer))
    }

    func testFailedTransferToPlaceholderBeneficiaryIsShown() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try makeHistoryFilter(for: chainAsset)

        let failedNovaFeeTransfer = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: placeholderBeneficiary(),
            callPath: .transferKeepAlive,
            status: .failed
        )

        XCTAssertTrue(filter.shouldDisplayOperation(model: failedNovaFeeTransfer))
    }

    func testFilterKeepsTransfersBetweenUserAccounts() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try makeHistoryFilter(for: chainAsset)

        let userTransfer = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: Data(repeating: 0x22, count: 32)
        )

        XCTAssertTrue(filter.shouldDisplayOperation(model: userTransfer))
    }

    func testFilterKeepsStakingExtrinsicRows() throws {
        let chainAsset = makeChainAsset(stakings: [.subtensor])
        let filter = try makeHistoryFilter(for: chainAsset)

        let stakingExtrinsic = try makeTransfer(
            for: chainAsset,
            sender: Data(repeating: 0x11, count: 32),
            receiver: subnetAccountId(netuid: 0),
            callPath: CallCodingPath(moduleName: "SubtensorModule", callName: "add_stake")
        )

        XCTAssertTrue(filter.shouldDisplayOperation(model: stakingExtrinsic))
    }
}
