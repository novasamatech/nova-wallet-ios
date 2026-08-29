import XCTest
@testable import novawallet
import SubstrateSdk
import Operation_iOS
import BigInt

final class HydraExchangeRatioConstantsTests: XCTestCase {
    func testXYKRatioConstantsAddressTheXYKPallet() {
        XCTAssertEqual(HydraXYK.maxInRatioPath.moduleName, "XYK")
        XCTAssertEqual(HydraXYK.maxInRatioPath.constantName, "MaxInRatio")
        XCTAssertEqual(HydraXYK.maxOutRatioPath.moduleName, "XYK")
        XCTAssertEqual(HydraXYK.maxOutRatioPath.constantName, "MaxOutRatio")
    }

    func testOmnipoolRatioConstantsAddressTheOmnipoolPallet() {
        XCTAssertEqual(HydraOmnipool.maxInRatioPath.moduleName, "Omnipool")
        XCTAssertEqual(HydraOmnipool.maxInRatioPath.constantName, "MaxInRatio")
        XCTAssertEqual(HydraOmnipool.maxOutRatioPath.moduleName, "Omnipool")
        XCTAssertEqual(HydraOmnipool.maxOutRatioPath.constantName, "MaxOutRatio")
    }

    func testMissingXYKRatioFailsClosedWithoutDisturbingTheOmnipoolRatios() throws {
        let codingFactory = try makeCodingFactory(
            xykRatios: ["MaxOutRatio": 3],
            omnipoolRatios: ["MaxInRatio": 3, "MaxOutRatio": 3]
        )

        XCTAssertThrowsError(try fetchRatio(at: HydraXYK.maxInRatioPath, using: codingFactory)) { error in
            guard
                let storageError = error as? StorageDecodingOperationError,
                storageError == .invalidStoragePath else {
                return XCTFail("unexpected error \(error)")
            }
        }

        XCTAssertEqual(try fetchRatio(at: HydraXYK.maxOutRatioPath, using: codingFactory), 3)
        XCTAssertEqual(try fetchRatio(at: HydraOmnipool.maxInRatioPath, using: codingFactory), 3)
        XCTAssertEqual(try fetchRatio(at: HydraOmnipool.maxOutRatioPath, using: codingFactory), 3)
    }

    func testMissingOmnipoolRatioFailsClosedWithoutDisturbingTheXYKRatios() throws {
        let codingFactory = try makeCodingFactory(
            xykRatios: ["MaxInRatio": 3, "MaxOutRatio": 3],
            omnipoolRatios: ["MaxOutRatio": 3]
        )

        XCTAssertThrowsError(try fetchRatio(at: HydraOmnipool.maxInRatioPath, using: codingFactory)) { error in
            guard
                let storageError = error as? StorageDecodingOperationError,
                storageError == .invalidStoragePath else {
                return XCTFail("unexpected error \(error)")
            }
        }

        XCTAssertEqual(try fetchRatio(at: HydraXYK.maxInRatioPath, using: codingFactory), 3)
        XCTAssertEqual(try fetchRatio(at: HydraXYK.maxOutRatioPath, using: codingFactory), 3)
    }

    func testRatioConstantsDecodeAtFullBalanceWidth() throws {
        let wide = try XCTUnwrap(Balance("340282366920938463463374607431768211455"))

        let codingFactory = try makeCodingFactory(
            xykRatios: ["MaxInRatio": wide],
            omnipoolRatios: [:]
        )

        XCTAssertEqual(try fetchRatio(at: HydraXYK.maxInRatioPath, using: codingFactory), wide)
    }
}

private extension HydraExchangeRatioConstantsTests {
    func fetchRatio(at path: ConstantCodingPath, using codingFactory: RuntimeCoderFactoryProtocol) throws -> Balance {
        let coderFactoryOperation = RuntimeCodingServiceStub(
            factory: codingFactory
        ).fetchCoderFactoryOperation()

        let ratioOperation: BaseOperation<Balance> = PrimitiveConstantOperation.operation(
            for: path,
            dependingOn: coderFactoryOperation
        )

        ratioOperation.addDependency(coderFactoryOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: ratioOperation,
            dependencies: [coderFactoryOperation]
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
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
