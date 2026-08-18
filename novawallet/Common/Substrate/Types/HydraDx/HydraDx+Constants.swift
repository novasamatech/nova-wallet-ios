import Foundation

extension HydraDx {
    static var assetFeeParametersPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.dynamicFeesModule, constantName: "AssetFeeParameters")
    }

    static var protocolFeeParametersPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.dynamicFeesModule, constantName: "ProtocolFeeParameters")
    }

    static var nativeAssetIdPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.multiTxPaymentModule, constantName: "NativeAssetId")
    }
}
