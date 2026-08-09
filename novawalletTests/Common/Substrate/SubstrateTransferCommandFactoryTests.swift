import XCTest
@testable import novawallet
import SubstrateSdk
import BigInt

final class SubstrateTransferCommandFactoryTests: XCTestCase {
    func testKeepAliveSelectsTransferKeepAlive() throws {
        let factory = SubstrateTransferCommandFactory()
        let info = NativeTokenStorageInfo(canTransferAll: true, transferCallPath: .transferAllowDeath)

        let (_, keepAlivePath) = try factory.addingTransferCommand(
            to: RecordingExtrinsicBuilder(),
            amount: .concrete(value: 100),
            recipient: AccountId(repeating: 1, count: 32),
            assetStorageInfo: .native(info: info),
            keepingSenderAlive: true
        )

        XCTAssertEqual(keepAlivePath, .transferKeepAlive)

        let (_, allowDeathPath) = try factory.addingTransferCommand(
            to: RecordingExtrinsicBuilder(),
            amount: .concrete(value: 100),
            recipient: AccountId(repeating: 1, count: 32),
            assetStorageInfo: .native(info: info),
            keepingSenderAlive: false
        )

        XCTAssertEqual(allowDeathPath, .transferAllowDeath)
    }

    func testKeepAliveDoesNotTakeTransferAll() throws {
        let factory = SubstrateTransferCommandFactory()
        let info = NativeTokenStorageInfo(canTransferAll: true, transferCallPath: .transferAllowDeath)

        let (_, path) = try factory.addingTransferCommand(
            to: RecordingExtrinsicBuilder(),
            amount: .all(value: 100),
            recipient: AccountId(repeating: 1, count: 32),
            assetStorageInfo: .native(info: info),
            keepingSenderAlive: true
        )

        XCTAssertEqual(path, .transferKeepAlive)
    }

    func testOrmlIgnoresKeepAliveFlag() throws {
        let factory = SubstrateTransferCommandFactory()
        let info = OrmlTokenStorageInfo(
            currencyId: .stringValue("0"),
            currencyData: Data(),
            module: "Tokens",
            existentialDeposit: 1,
            canTransferAll: true
        )

        for keepingSenderAlive in [true, false] {
            let (_, path) = try factory.addingTransferCommand(
                to: RecordingExtrinsicBuilder(),
                amount: .concrete(value: 100),
                recipient: AccountId(repeating: 1, count: 32),
                assetStorageInfo: .orml(info: info),
                keepingSenderAlive: keepingSenderAlive
            )

            XCTAssertEqual(path, CallCodingPath(moduleName: "Tokens", callName: "transfer"))
        }
    }

    func testAssetsIgnoresKeepAliveFlag() throws {
        let factory = SubstrateTransferCommandFactory()
        let info = AssetsPalletStorageInfo(assetId: .stringValue("1"), assetIdString: "1", palletName: "Assets")

        for keepingSenderAlive in [true, false] {
            let (_, path) = try factory.addingTransferCommand(
                to: RecordingExtrinsicBuilder(),
                amount: .concrete(value: 100),
                recipient: AccountId(repeating: 1, count: 32),
                assetStorageInfo: .statemine(info: info),
                keepingSenderAlive: keepingSenderAlive
            )

            XCTAssertEqual(path, CallCodingPath(moduleName: "Assets", callName: "transfer"))
        }
    }
}

final class RecordingExtrinsicBuilder: ExtrinsicBuilderProtocol {
    private(set) var addedCalls: [CallCodingPath] = []

    func with<A: Codable>(address _: A) throws -> Self {
        self
    }

    func with(nonce _: UInt32) -> Self {
        self
    }

    func getNonce() -> UInt32? {
        nil
    }

    func with(era _: Era, blockHash _: String) -> Self {
        self
    }

    func with(tip _: BigUInt) -> Self {
        self
    }

    func with(metadataHash _: Data) -> Self {
        self
    }

    func with(batchType _: ExtrinsicBatch) -> Self {
        self
    }

    func with(signaturePayloadFormat _: ExtrinsicSignaturePayloadFormat) -> Self {
        self
    }

    func adding<T: RuntimeCallable>(call: T) throws -> Self {
        addedCalls.append(CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        return self
    }

    func adding<T: RuntimeCallable>(call: T, at _: Int) throws -> Self {
        addedCalls.append(CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        return self
    }

    func adding(rawCall _: Data) throws -> Self {
        self
    }

    func adding(transactionExtension _: TransactionExtending) -> Self {
        self
    }

    func with(runtimeJsonContext _: RuntimeJsonContext) -> Self {
        self
    }

    func wrappingCalls(for _: (JSON) throws -> JSON) throws -> Self {
        self
    }

    func batchingCalls(with _: RuntimeMetadataProtocol) throws -> Self {
        self
    }

    func getCalls() -> [JSON] {
        []
    }

    func resetCalls() -> Self {
        self
    }

    func signing(
        by _: @escaping (Data) throws -> Data,
        of _: CryptoType,
        using _: DynamicScaleEncodingFactoryProtocol,
        metadata _: RuntimeMetadataProtocol
    ) throws -> Self {
        throw CommonError.dataCorruption
    }

    func signing(
        by _: @escaping (Data) throws -> JSON,
        using _: DynamicScaleEncodingFactoryProtocol,
        metadata _: RuntimeMetadataProtocol
    ) throws -> Self {
        throw CommonError.dataCorruption
    }

    func buildRawSignature(
        using _: @escaping (Data) throws -> Data,
        encodingFactory _: DynamicScaleEncodingFactoryProtocol,
        metadata _: RuntimeMetadataProtocol
    ) throws -> Data {
        throw CommonError.dataCorruption
    }

    func buildExtrinsicSignatureParams(
        encodingFactory _: DynamicScaleEncodingFactoryProtocol,
        metadata _: RuntimeMetadataProtocol
    ) throws -> ExtrinsicSignatureParams {
        throw CommonError.dataCorruption
    }

    func buildSignaturePayload(
        encodingFactory _: DynamicScaleEncodingFactoryProtocol,
        metadata _: RuntimeMetadataProtocol
    ) throws -> Data {
        throw CommonError.dataCorruption
    }

    func build(
        using _: DynamicScaleEncodingFactoryProtocol,
        metadata _: RuntimeMetadataProtocol
    ) throws -> Data {
        throw CommonError.dataCorruption
    }

    func makeMemo() -> ExtrinsicBuilderMemoProtocol {
        fatalError("unused")
    }
}
