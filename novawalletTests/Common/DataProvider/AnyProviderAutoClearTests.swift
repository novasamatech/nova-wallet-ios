import XCTest
@testable import novawallet
import Operation_iOS

class AnyProviderAutoClearTests: XCTestCase {

    func testPerformanceExample() throws {
        // given

        let cleaner = AnyProviderAutoCleaner()
        let singleValueProvider = StakingLocalSubscriptionFactoryStub()
        let chain = ChainModelGenerator.generate(count: 1).first!

        var provider: AnyDataProvider<DecodedBigUInt>? = try singleValueProvider.getMinNominatorBondProvider(
            for: chain.chainId,
            missingEntryStrategy: .emitError
        )

        // when

        XCTAssertNotNil(provider)

        cleaner.clear(dataProvider: &provider)

        XCTAssertNil(provider)
    }

}
