import XCTest
import Cuckoo
import Foundation_iOS
@testable import novawallet

final class FormatterCacheTests: XCTestCase {
    private var factory: MockAssetBalanceFormatterFactoryProtocol!
    private var cache: FormatterCacheProtocol!

    private let testLocale = Locale(identifier: "en_US")
    private let testInfo = AssetBalanceDisplayInfo(
        displayPrecision: 4,
        assetPrecision: 10,
        symbol: "DOT",
        symbolValueSeparator: " ",
        symbolPosition: .suffix,
        icon: nil
    )

    override func setUp() {
        super.setUp()

        factory = MockAssetBalanceFormatterFactoryProtocol()
        cache = FormatterCache(factory: factory)
    }

    override func tearDown() {
        factory = nil
        cache = nil

        super.tearDown()
    }

    // MARK: - Display Formatter Tests

    func testDisplayFormatter_createdOnFirstCall() {
        // given
        let expectedFormatter = NumberFormatter()
        stubDisplayFormatter(returning: expectedFormatter)

        // when
        let result = cache.displayFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createDisplayFormatter(for: any())
    }

    func testDisplayFormatter_retrievedFromCache() {
        // given
        let expectedFormatter = NumberFormatter()
        stubDisplayFormatter(returning: expectedFormatter)

        // when
        _ = cache.displayFormatter(for: testInfo, locale: testLocale)
        let result = cache.displayFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createDisplayFormatter(for: any())
    }

    func testDisplayFormatter_recreatedAfterClear() {
        // given
        let firstFormatter = NumberFormatter()
        let secondFormatter = NumberFormatter()
        stubDisplayFormatter(returning: firstFormatter, secondFormatter)

        // when
        let firstResult = cache.displayFormatter(for: testInfo, locale: testLocale)
        cache.clearCache()
        let secondResult = cache.displayFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(firstResult === firstFormatter)
        XCTAssertTrue(secondResult === secondFormatter)
        verify(factory, times(2)).createDisplayFormatter(for: any())
    }

    // MARK: - Token Formatter Tests

    func testTokenFormatter_createdOnFirstCall() {
        // given
        let expectedFormatter = createMockTokenFormatter()
        stubTokenFormatter(returning: expectedFormatter)

        // when
        let result = cache.tokenFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createTokenFormatter(
            for: any(),
            roundingMode: any(),
            useSuffixForBigNumbers: any()
        )
    }

    func testTokenFormatter_retrievedFromCache() {
        // given
        let expectedFormatter = createMockTokenFormatter()
        stubTokenFormatter(returning: expectedFormatter)

        // when
        _ = cache.tokenFormatter(for: testInfo, locale: testLocale)
        let result = cache.tokenFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createTokenFormatter(
            for: any(),
            roundingMode: any(),
            useSuffixForBigNumbers: any()
        )
    }

    func testTokenFormatter_recreatedAfterClear() {
        // given
        let firstFormatter = createMockTokenFormatter()
        let secondFormatter = createMockTokenFormatter()
        stubTokenFormatter(returning: firstFormatter, secondFormatter)

        // when
        let firstResult = cache.tokenFormatter(for: testInfo, locale: testLocale)
        cache.clearCache()
        let secondResult = cache.tokenFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(firstResult === firstFormatter)
        XCTAssertTrue(secondResult === secondFormatter)
        verify(factory, times(2)).createTokenFormatter(
            for: any(),
            roundingMode: any(),
            useSuffixForBigNumbers: any()
        )
    }

    // MARK: - Asset Price Formatter Tests

    func testAssetPriceFormatter_createdOnFirstCall() {
        // given
        let expectedFormatter = createMockTokenFormatter()
        stubAssetPriceFormatter(returning: expectedFormatter)

        // when
        let result = cache.assetPriceFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createAssetPriceFormatter(
            for: any(),
            useSuffixForBigNumbers: any()
        )
    }

    func testAssetPriceFormatter_retrievedFromCache() {
        // given
        let expectedFormatter = createMockTokenFormatter()
        stubAssetPriceFormatter(returning: expectedFormatter)

        // when
        _ = cache.assetPriceFormatter(for: testInfo, locale: testLocale)
        let result = cache.assetPriceFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createAssetPriceFormatter(
            for: any(),
            useSuffixForBigNumbers: any()
        )
    }

    func testAssetPriceFormatter_recreatedAfterClear() {
        // given
        let firstFormatter = createMockTokenFormatter()
        let secondFormatter = createMockTokenFormatter()
        stubAssetPriceFormatter(returning: firstFormatter, secondFormatter)

        // when
        let firstResult = cache.assetPriceFormatter(for: testInfo, locale: testLocale)
        cache.clearCache()
        let secondResult = cache.assetPriceFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(firstResult === firstFormatter)
        XCTAssertTrue(secondResult === secondFormatter)
        verify(factory, times(2)).createAssetPriceFormatter(
            for: any(),
            useSuffixForBigNumbers: any()
        )
    }

    // MARK: - Input Formatter Tests

    func testInputFormatter_createdOnFirstCall() {
        // given
        let expectedFormatter = NumberFormatter()
        stubInputFormatter(returning: expectedFormatter)

        // when
        let result = cache.inputFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createInputFormatter(for: any())
    }

    func testInputFormatter_retrievedFromCache() {
        // given
        let expectedFormatter = NumberFormatter()
        stubInputFormatter(returning: expectedFormatter)

        // when
        _ = cache.inputFormatter(for: testInfo, locale: testLocale)
        let result = cache.inputFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(result === expectedFormatter)
        verify(factory, times(1)).createInputFormatter(for: any())
    }

    func testInputFormatter_recreatedAfterClear() {
        // given
        let firstFormatter = NumberFormatter()
        let secondFormatter = NumberFormatter()
        stubInputFormatter(returning: firstFormatter, secondFormatter)

        // when
        let firstResult = cache.inputFormatter(for: testInfo, locale: testLocale)
        cache.clearCache()
        let secondResult = cache.inputFormatter(for: testInfo, locale: testLocale)

        // then
        XCTAssertTrue(firstResult === firstFormatter)
        XCTAssertTrue(secondResult === secondFormatter)
        verify(factory, times(2)).createInputFormatter(for: any())
    }

    // MARK: - Locale Change Tests

    func testDisplayFormatter_recreatedOnLocaleChange() {
        // given
        let firstFormatter = NumberFormatter()
        let secondFormatter = NumberFormatter()
        stubDisplayFormatter(returning: firstFormatter, secondFormatter)

        let secondLocale = Locale(identifier: "de_DE")

        // when
        let firstResult = cache.displayFormatter(for: testInfo, locale: testLocale)
        let secondResult = cache.displayFormatter(for: testInfo, locale: secondLocale)

        // then
        XCTAssertTrue(firstResult === firstFormatter)
        XCTAssertTrue(secondResult === secondFormatter)
        verify(factory, times(2)).createDisplayFormatter(for: any())
    }
}

// MARK: - Private Helpers

private extension FormatterCacheTests {
    func createMockTokenFormatter() -> TokenFormatter {
        TokenFormatter(
            decimalFormatter: NumberFormatter(),
            tokenSymbol: "DOT",
            separator: " ",
            position: .suffix
        )
    }

    func stubDisplayFormatter(returning formatters: LocalizableDecimalFormatting...) {
        var formatters = formatters
        stub(factory) { stub in
            when(stub.createDisplayFormatter(for: any())).then { _ in
                let formatter = formatters.isEmpty ? formatters.last! : formatters.removeFirst()
                return LocalizableResource { _ in formatter }
            }
        }
    }

    func stubTokenFormatter(returning formatters: TokenFormatter...) {
        var formatters = formatters
        stub(factory) { stub in
            when(stub.createTokenFormatter(
                for: any(),
                roundingMode: any(),
                useSuffixForBigNumbers: any()
            )).then { _, _, _ in
                let formatter = formatters.isEmpty ? formatters.last! : formatters.removeFirst()
                return LocalizableResource { _ in formatter }
            }
        }
    }

    func stubAssetPriceFormatter(returning formatters: TokenFormatter...) {
        var formatters = formatters
        stub(factory) { stub in
            when(stub.createAssetPriceFormatter(
                for: any(),
                useSuffixForBigNumbers: any()
            )).then { _, _ in
                let formatter = formatters.isEmpty ? formatters.last! : formatters.removeFirst()
                return LocalizableResource { _ in formatter }
            }
        }
    }

    func stubInputFormatter(returning formatters: NumberFormatter...) {
        var formatters = formatters
        stub(factory) { stub in
            when(stub.createInputFormatter(for: any())).then { _ in
                let formatter = formatters.isEmpty ? formatters.last! : formatters.removeFirst()
                return LocalizableResource { _ in formatter }
            }
        }
    }
}
