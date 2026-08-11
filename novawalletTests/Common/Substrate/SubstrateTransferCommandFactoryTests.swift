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

    func testOrmlCommissionTransferUsesKeepAliveCallPath() throws {
        let factory = SubstrateTransferCommandFactory()

        let expectations: [(Bool, CallCodingPath)] = [
            (true, .tokensTransferKeepAlive),
            (false, .tokensTransfer)
        ]

        for (keepingSenderAlive, expectedPath) in expectations {
            let (_, path) = try factory.addingTransferCommand(
                to: RecordingExtrinsicBuilder(),
                amount: .concrete(value: 100),
                recipient: AccountId(repeating: 1, count: 32),
                assetStorageInfo: .orml(info: Self.ormlInfo()),
                keepingSenderAlive: keepingSenderAlive
            )

            XCTAssertEqual(path, expectedPath)
        }
    }

    func testOrmlKeepAliveDoesNotTakeTransferAll() throws {
        let factory = SubstrateTransferCommandFactory()

        let (_, path) = try factory.addingTransferCommand(
            to: RecordingExtrinsicBuilder(),
            amount: .all(value: 100),
            recipient: AccountId(repeating: 1, count: 32),
            assetStorageInfo: .orml(info: Self.ormlInfo()),
            keepingSenderAlive: true
        )

        XCTAssertEqual(path, .tokensTransferKeepAlive)
    }

    func testKeepAliveRejectedWhenPalletHasNoKeepAliveVariant() throws {
        let factory = SubstrateTransferCommandFactory()

        let unsupported: [AssetStorageInfo] = [
            .statemine(
                info: AssetsPalletStorageInfo(
                    assetId: .stringValue("1"),
                    assetIdString: "1",
                    palletName: "Assets"
                )
            ),
            .equilibrium(extras: EquilibriumAssetExtras(assetId: 1, transfersEnabled: true))
        ]

        for assetStorageInfo in unsupported {
            XCTAssertThrowsError(
                try factory.addingTransferCommand(
                    to: RecordingExtrinsicBuilder(),
                    amount: .concrete(value: 100),
                    recipient: AccountId(repeating: 1, count: 32),
                    assetStorageInfo: assetStorageInfo,
                    keepingSenderAlive: true
                )
            ) { error in
                switch error {
                case SubstrateTransferCommandFactoryError.keepAliveNotSupported:
                    break
                default:
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }
}

private extension SubstrateTransferCommandFactoryTests {
    static func ormlInfo() -> OrmlTokenStorageInfo {
        OrmlTokenStorageInfo(
            currencyId: .stringValue("0"),
            currencyData: Data(),
            module: "Tokens",
            existentialDeposit: 1,
            canTransferAll: true
        )
    }
}
