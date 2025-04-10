import Foundation

extension SystemPallet {
    static var blockWeights: ConstantCodingPath {
        ConstantCodingPath(moduleName: name, constantName: "BlockWeights")
    }

    static var blockHashCount: ConstantCodingPath {
        ConstantCodingPath(moduleName: name, constantName: "BlockHashCount")
    }
}
