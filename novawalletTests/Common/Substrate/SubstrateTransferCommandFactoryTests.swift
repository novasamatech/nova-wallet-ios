import XCTest
@testable import novawallet
import SubstrateSdk
import BigInt

final class SubstrateTransferCommandFactoryTests: XCTestCase {
    func testOrmlTransferUsesPlainTransferForEveryModule() throws {
        let factory = SubstrateTransferCommandFactory()

        let cases: [(AssetStorageInfo, String)] = [
            (.orml(info: Self.ormlInfo(module: "Tokens")), "Tokens"),
            (.ormlHydrationEvm(info: Self.ormlInfo(module: "Currencies")), "Currencies")
        ]

        for (assetStorageInfo, expectedModule) in cases {
            let (_, path) = try factory.addingTransferCommand(
                to: RecordingExtrinsicBuilder(),
                amount: .concrete(value: 100),
                recipient: AccountId(repeating: 1, count: 32),
                assetStorageInfo: assetStorageInfo
            )

            XCTAssertEqual(path?.moduleName, expectedModule)
            XCTAssertEqual(path?.callName, "transfer")
        }
    }

    func testNativeTransferUsesConfiguredCallPath() throws {
        let factory = SubstrateTransferCommandFactory()
        let info = NativeTokenStorageInfo(canTransferAll: true, transferCallPath: .transferAllowDeath)

        let (_, path) = try factory.addingTransferCommand(
            to: RecordingExtrinsicBuilder(),
            amount: .concrete(value: 100),
            recipient: AccountId(repeating: 1, count: 32),
            assetStorageInfo: .native(info: info)
        )

        XCTAssertEqual(path, .transferAllowDeath)
    }

    func testAssetTypesUnsupportedByCommissionStillEncodeTransfers() throws {
        let factory = SubstrateTransferCommandFactory()

        let assetStorageInfos: [AssetStorageInfo] = [
            .statemine(
                info: AssetsPalletStorageInfo(
                    assetId: .stringValue("1"),
                    assetIdString: "1",
                    palletName: "Assets"
                )
            ),
            .equilibrium(extras: EquilibriumAssetExtras(assetId: 1, transfersEnabled: true))
        ]

        for assetStorageInfo in assetStorageInfos {
            XCTAssertNoThrow(
                try factory.addingTransferCommand(
                    to: RecordingExtrinsicBuilder(),
                    amount: .concrete(value: 100),
                    recipient: AccountId(repeating: 1, count: 32),
                    assetStorageInfo: assetStorageInfo
                )
            )
        }
    }
}

private extension SubstrateTransferCommandFactoryTests {
    static func ormlInfo(module: String) -> OrmlTokenStorageInfo {
        OrmlTokenStorageInfo(
            currencyId: .stringValue("0"),
            currencyData: Data(),
            module: module,
            existentialDeposit: 1,
            canTransferAll: true
        )
    }
}
