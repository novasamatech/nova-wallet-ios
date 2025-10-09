import Foundation

extension BabePallet {
    static var currentSlotPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "CurrentSlot")
    }

    static var genesisSlotPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "GenesisSlot")
    }

    static var currentEpochPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "EpochIndex")
    }

    static var blockTimePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: name, constantName: "ExpectedBlockTime")
    }

    static var sessionLengthPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: name, constantName: "EpochDuration")
    }
}
