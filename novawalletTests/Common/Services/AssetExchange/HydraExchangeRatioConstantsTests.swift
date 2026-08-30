import XCTest
@testable import novawallet
import SubstrateSdk
import Operation_iOS
import BigInt

final class HydraExchangeRatioConstantsTests: XCTestCase {
    func testEachPalletReadsItsOwnRatiosRatherThanTheOtherPalletsPair() throws {
        let codingFactory = try makeCodingFactory(
            xykRatios: ["MaxInRatio": 3, "MaxOutRatio": 3],
            omnipoolRatios: ["MaxInRatio": 5, "MaxOutRatio": 7]
        )

        XCTAssertEqual(
            try fetchRatios(for: .xyk, using: codingFactory),
            HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)
        )

        XCTAssertEqual(
            try fetchRatios(for: .omnipool, using: codingFactory),
            HydraExchangeTradeLimits.Ratios(maxInRatio: 5, maxOutRatio: 7)
        )
    }

    func testMissingXYKRatioFailsTheXYKQuoteWithoutDisturbingTheOmnipoolRatios() throws {
        let codingFactory = try makeCodingFactory(
            xykRatios: ["MaxOutRatio": 3],
            omnipoolRatios: ["MaxInRatio": 5, "MaxOutRatio": 7]
        )

        assertRatiosUnavailable(
            try fetchRatios(for: .xyk, using: codingFactory),
            pallet: "XYK"
        )

        XCTAssertEqual(
            try fetchRatios(for: .omnipool, using: codingFactory),
            HydraExchangeTradeLimits.Ratios(maxInRatio: 5, maxOutRatio: 7)
        )
    }

    func testMissingOmnipoolRatioFailsTheOmnipoolQuoteWithoutDisturbingTheXYKRatios() throws {
        let codingFactory = try makeCodingFactory(
            xykRatios: ["MaxInRatio": 3, "MaxOutRatio": 3],
            omnipoolRatios: ["MaxOutRatio": 7]
        )

        assertRatiosUnavailable(
            try fetchRatios(for: .omnipool, using: codingFactory),
            pallet: "Omnipool"
        )

        XCTAssertEqual(
            try fetchRatios(for: .xyk, using: codingFactory),
            HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)
        )
    }
}

private extension HydraExchangeRatioConstantsTests {
    func fetchRatios(
        for constants: HydraExchangeTradeLimits.RatioConstants,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraExchangeTradeLimits.Ratios {
        let coderFactoryOperation = RuntimeCodingServiceStub(
            factory: codingFactory
        ).fetchCoderFactoryOperation()

        let wrapper = HydraExchangeTradeLimits.createRatiosWrapper(
            for: constants,
            dependingOn: coderFactoryOperation
        )

        let totalWrapper = wrapper.insertingHead(operations: [coderFactoryOperation])

        OperationQueue().addOperations(totalWrapper.allOperations, waitUntilFinished: true)

        return try totalWrapper.targetOperation.extractNoCancellableResultData()
    }

    func assertRatiosUnavailable<T>(
        _ expression: @autoclosure () throws -> T,
        pallet: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard
                case let HydraExchangeTradeLimitError.ratiosUnavailable(reportedPallet) = error,
                reportedPallet == pallet else {
                return XCTFail("unexpected error \(error)", file: file, line: line)
            }
        }
    }

    func makeCodingFactory(
        xykRatios: [String: Balance],
        omnipoolRatios: [String: Balance]
    ) throws -> RuntimeCoderFactoryProtocol {
        let metadata = RuntimeMetadata(
            modules: [
                makeModule(name: HydraXYK.name, constants: xykRatios, index: 74),
                makeModule(name: HydraOmnipool.moduleName, constants: omnipoolRatios, index: 51)
            ],
            extrinsic: ExtrinsicMetadata(version: 4, signedExtensions: [])
        )

        let catalog = try RuntimeHelper.createTypeRegistryCatalog(
            from: "runtime-default",
            networkName: "runtime-westend",
            runtimeMetadataName: "westend-metadata"
        )

        return RuntimeCoderFactory(
            catalog: catalog,
            specVersion: 9260,
            txVersion: 11,
            metadata: metadata
        )
    }

    func makeModule(name: String, constants: [String: Balance], index: UInt8) -> ModuleMetadata {
        ModuleMetadata(
            name: name,
            storage: nil,
            calls: nil,
            events: nil,
            constants: constants.map { constantName, value in
                ModuleConstantMetadata(
                    name: constantName,
                    type: PrimitiveType.u128.name,
                    value: encodeU128(value),
                    documentation: []
                )
            },
            errors: [],
            index: index
        )
    }

    func encodeU128(_ value: Balance) -> Data {
        let bigEndian = value.serialize()
        let padding = Data(repeating: 0, count: max(0, 16 - bigEndian.count))

        return Data((padding + bigEndian).reversed())
    }
}
