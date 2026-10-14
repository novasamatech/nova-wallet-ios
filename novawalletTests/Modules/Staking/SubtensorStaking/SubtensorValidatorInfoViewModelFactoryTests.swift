import Foundation_iOS
@testable import novawallet
import XCTest

final class SubtensorValidatorInfoViewModelFactoryTests: XCTestCase {
    func testCoverageIsIndependentFromMissingDetailAndRates() {
        let chainAsset = SubtensorFlowChainWorld.chainAsset()
        let balanceFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub()))
        let factory = SubtensorValidatorInfoViewModelFactory(chainAsset: chainAsset, balanceViewModelFactory: balanceFactory)
        var input = SubtensorValidatorInfoInput(
            target: .root,
            hotkey: Data(repeating: 7, count: 32),
            detail: nil,
            annualRate: .loading,
            alphaPrice: .loading,
            price: nil
        )
        let loading = factory.createViewModel(for: input, locale: Locale(identifier: "en"))
        XCTAssertEqual(loading.coverage, .loading)
        XCTAssertNil(loading.staking)
        input.coverage = .loaded(value: .init(permitted: 2, total: 3, blockHash: "hash"))
        let loaded = factory.createViewModel(for: input, locale: Locale(identifier: "en"))
        XCTAssertEqual(loaded.coverage, .loaded(value: "2 of 3"))
        XCTAssertNil(loaded.staking)
        input.coverage = .loaded(value: nil)
        let unavailable = factory.createViewModel(for: input, locale: Locale(identifier: "en"))
        XCTAssertEqual(unavailable.coverage, .loaded(value: "—"))
        XCTAssertEqual(unavailable.account.address, loaded.account.address)
    }
}
