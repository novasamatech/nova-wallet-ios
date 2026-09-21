import XCTest
@testable import novawallet
import Operation_iOS

final class AssetHubSwapHistoryFiltersProviderTests: XCTestCase {
    private let beneficiary = AccountId(repeating: 9, count: 32)

    func testNonSwapHubChainContributesNoFilters() throws {
        let filters = try createFilters(hasSwapHub: false, beneficiaries: [beneficiary])

        XCTAssertTrue(filters.isEmpty)
    }

    func testSwapHubChainSuppressesTransferToBeneficiary() throws {
        let filters = try createFilters(hasSwapHub: true, beneficiaries: [beneficiary])
        let filter = try XCTUnwrap(filters.first)

        XCTAssertFalse(filter.shouldDisplayOperation(model: try createTransfer(to: beneficiary)))
    }

    func testSwapHubChainKeepsUnrelatedTransfer() throws {
        let filters = try createFilters(hasSwapHub: true, beneficiaries: [beneficiary])
        let filter = try XCTUnwrap(filters.first)

        XCTAssertTrue(filter.shouldDisplayOperation(model: try createTransfer(to: AccountId(repeating: 3, count: 32))))
    }

    func testRotatedBeneficiaryIsStillSuppressed() throws {
        let historical = AccountId(repeating: 8, count: 32)
        let filters = try createFilters(hasSwapHub: true, beneficiaries: [beneficiary, historical])
        let filter = try XCTUnwrap(filters.first)

        XCTAssertFalse(filter.shouldDisplayOperation(model: try createTransfer(to: historical)))
    }

    func testMalformedBeneficiaryAddressesAreReportedAsInvalid() {
        let resolved = AssetExchangeCommissionConstants.assetHubHistoryBeneficiaries(for: "unconfigured")

        XCTAssertTrue(resolved.accountIds.isEmpty)
        XCTAssertTrue(resolved.invalid.isEmpty)
    }
}

private extension AssetHubSwapHistoryFiltersProviderTests {
    var chainAssetWithSwapHub: ChainAsset {
        get throws { try createChainAsset(hasSwapHub: true) }
    }

    func createChainAsset(hasSwapHub: Bool) throws -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 2,
            addressPrefix: 42,
            hasSwapHub: hasSwapHub
        )

        return ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first))
    }

    func createFilters(
        hasSwapHub: Bool,
        beneficiaries: Set<AccountId>
    ) throws -> [TransactionHistoryLocalFilterProtocol] {
        let provider = AssetHubSwapHistoryFiltersProvider(
            chainAsset: try createChainAsset(hasSwapHub: hasSwapHub),
            beneficiaries: beneficiaries,
            logger: Logger.shared
        )

        let wrapper = provider.createFiltersWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func createTransfer(to recipient: AccountId) throws -> TransactionHistoryItem {
        let chainAsset = try chainAssetWithSwapHub

        return TransactionHistoryItem(
            identifier: UUID().uuidString,
            source: .substrate,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId,
            sender: try AccountId(repeating: 1, count: 32).toAddress(using: chainAsset.chain.chainFormat),
            receiver: try recipient.toAddress(using: chainAsset.chain.chainFormat),
            amountInPlank: "10",
            status: .success,
            txHash: Data.random(of: 32)!.toHex(includePrefix: true),
            timestamp: 0,
            fee: nil,
            feeAssetId: nil,
            blockNumber: nil,
            txIndex: nil,
            callPath: .transfer,
            call: nil,
            swap: nil
        )
    }
}
