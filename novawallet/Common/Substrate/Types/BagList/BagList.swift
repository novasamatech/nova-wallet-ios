import Foundation
import SubstrateSdk
import BigInt

enum BagList {
    static var defaultModuleName: String {
        "VoterList"
    }

    static var possibleModuleNames: [String] {
        [defaultModuleName, "BagsList"]
    }

    struct Node: Codable, Equatable {
        @StringCodable var bagUpper: BigUInt
        @StringCodable var score: BigUInt
    }
}
