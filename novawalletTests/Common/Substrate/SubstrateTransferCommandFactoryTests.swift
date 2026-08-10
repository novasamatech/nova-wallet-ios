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
}
