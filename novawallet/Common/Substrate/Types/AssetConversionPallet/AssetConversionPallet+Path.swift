import Foundation

extension AssetConversionPallet {
    static var poolsPath: StorageCodingPath {
        getPoolsPath(for: AssetConversionPallet.name)
    }

    static func getPoolsPath(for moduleName: String) -> StorageCodingPath {
        StorageCodingPath(moduleName: moduleName, itemName: "Pools")
    }
}
