import Foundation

extension HydraDx {
    static var hubAssetIdPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.omniPoolModule, constantName: "HubAssetId")
    }

    static var assetFeeParametersPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.dynamicFeesModule, constantName: "AssetFeeParameters")
    }

    static var protocolFeeParametersPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.dynamicFeesModule, constantName: "ProtocolFeeParameters")
    }
}
