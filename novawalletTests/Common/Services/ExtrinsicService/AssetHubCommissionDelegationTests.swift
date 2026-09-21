import XCTest
@testable import novawallet
import SubstrateSdk
import BigInt

final class AssetHubCommissionDelegationTests: XCTestCase {
    func testCommissionedBatchResolvesToSwapPermission() throws {
        let context = try Self.codingFactory().createRuntimeJsonContext()

        let call = try Self.makeBatch(
            calls: [Self.swapCall(context: context), Self.nativeCollectionCall(context: context)],
            path: UtilityPallet.batchAllPath,
            context: context
        )

        XCTAssertEqual(
            try AssetHubExchangeDelegationPermission.permissionPath(for: call, context: context),
            AssetConversionPallet.swapExactTokenForTokensPath
        )
    }

    func testAssetsCollectionBatchResolvesToSwapPermission() throws {
        let context = try Self.codingFactory().createRuntimeJsonContext()

        let call = try Self.makeBatch(
            calls: [Self.swapCall(context: context), Self.assetsCollectionCall(context: context)],
            path: UtilityPallet.batchAllPath,
            context: context
        )

        XCTAssertEqual(
            try AssetHubExchangeDelegationPermission.permissionPath(for: call, context: context),
            AssetConversionPallet.swapExactTokenForTokensPath
        )
    }

    func testConfiguredAssetsPalletResolvesToSwapPermission() throws {
        let context = try Self.codingFactory().createRuntimeJsonContext()
        let collection = try RuntimeCall(
            path: PalletAssets.assetsTransferKeepAlive(for: "ConfiguredAssets"),
            args: PalletAssets.TransferCall(
                assetId: .stringValue("1984"),
                target: .accoundId(AccountId(repeating: 7, count: 32)),
                amount: 10
            )
        ).anyRuntimeCall(with: context)
        let call = try Self.makeBatch(
            calls: [Self.swapCall(context: context), collection],
            path: UtilityPallet.batchAllPath,
            context: context
        )
        XCTAssertEqual(try AssetHubExchangeDelegationPermission.permissionPath(
            for: call, context: context, supportedAssetsPallets: ["ConfiguredAssets"]
        ), AssetConversionPallet.swapExactTokenForTokensPath)
        XCTAssertEqual(try AssetHubExchangeDelegationPermission.permissionPath(
            for: call, context: context, supportedAssetsPallets: []
        ), UtilityPallet.batchAllPath)
    }

    func testConfiguredPalletNamesComeFromChainAssets() throws {
        let asset = AssetModel(
            assetId: 1, icon: nil, name: "Token", symbol: "TOK", precision: 6, priceId: nil,
            stakings: nil, type: AssetType.statemine.rawValue,
            typeExtras: try StatemineAssetExtras(assetId: "1984", palletName: "ConfiguredAssets").toScaleCompatibleJSON(),
            buyProviders: nil, sellProviders: nil, source: .remote
        )
        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 42)
        XCTAssertTrue(PalletAssets.palletNames(for: chain).contains("ConfiguredAssets"))
        XCTAssertTrue(PalletAssets.palletNames(for: chain).contains("Assets"))
    }

    func testUnrelatedBatchKeepsUtilityPermission() throws {
        let context = try Self.codingFactory().createRuntimeJsonContext()

        let extraLeaf = try Self.makeBatch(
            calls: [
                Self.swapCall(context: context),
                Self.nativeCollectionCall(context: context),
                Self.nativeCollectionCall(context: context)
            ],
            path: UtilityPallet.batchAllPath,
            context: context
        )

        XCTAssertEqual(
            try AssetHubExchangeDelegationPermission.permissionPath(for: extraLeaf, context: context),
            UtilityPallet.batchAllPath
        )

        let nonAtomic = try Self.makeBatch(
            calls: [Self.swapCall(context: context), Self.nativeCollectionCall(context: context)],
            path: UtilityPallet.batchPath,
            context: context
        )

        XCTAssertEqual(
            try AssetHubExchangeDelegationPermission.permissionPath(for: nonAtomic, context: context),
            UtilityPallet.batchPath
        )

        let wrongOrder = try Self.makeBatch(
            calls: [Self.nativeCollectionCall(context: context), Self.swapCall(context: context)],
            path: UtilityPallet.batchAllPath,
            context: context
        )

        XCTAssertEqual(
            try AssetHubExchangeDelegationPermission.permissionPath(for: wrongOrder, context: context),
            UtilityPallet.batchAllPath
        )
    }

    func testPlainCallKeepsItsOwnPermission() throws {
        let context = try Self.codingFactory().createRuntimeJsonContext()

        XCTAssertEqual(
            try AssetHubExchangeDelegationPermission.permissionPath(
                for: Self.swapCall(context: context),
                context: context
            ),
            AssetConversionPallet.swapExactTokenForTokensPath
        )
    }
}

private extension AssetHubCommissionDelegationTests {
    static func codingFactory() throws -> RuntimeCoderFactoryProtocol {
        try RuntimeCodingServiceStub.createWestendCodingFactory()
    }

    static func makeBatch(
        calls: [AnyRuntimeCall],
        path: CallCodingPath,
        context: RuntimeJsonContext
    ) throws -> AnyRuntimeCall {
        try AnyRuntimeCall(path: path, args: UtilityPallet.Call(calls: calls), context: context)
    }

    static func swapCall(context: RuntimeJsonContext) throws -> AnyRuntimeCall {
        let call = AssetConversionPallet.SwapExactTokensForTokensCall(
            path: [],
            amountIn: 1000,
            amountOutMin: 900,
            sendTo: AccountId(repeating: 5, count: 32),
            keepAlive: false
        )

        return try call.runtimeCall(for: AssetConversionPallet.name).anyRuntimeCall(with: context)
    }

    static func nativeCollectionCall(context: RuntimeJsonContext) throws -> AnyRuntimeCall {
        let call = SubstrateCallFactory().nativeTransfer(
            to: AccountId(repeating: 7, count: 32),
            amount: 10,
            callPath: .transferKeepAlive
        )

        return try call.anyRuntimeCall(with: context)
    }

    static func assetsCollectionCall(context: RuntimeJsonContext) throws -> AnyRuntimeCall {
        let args = PalletAssets.TransferCall(
            assetId: .stringValue("1984"),
            target: .accoundId(AccountId(repeating: 7, count: 32)),
            amount: 10
        )

        let call = RuntimeCall(path: PalletAssets.assetsTransferKeepAlive(for: "ForeignAssets"), args: args)

        return try call.anyRuntimeCall(with: context)
    }
}
