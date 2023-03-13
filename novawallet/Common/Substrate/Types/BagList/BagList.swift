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

    typealias Score = BigUInt

    struct Node: Codable, Equatable {
        @StringCodable var bagUpper: Score
        @StringCodable var score: Score
    }

    static let maxScore = BigUInt(UInt64.max)

    static func scoreFactor(for totalIssuance: BigUInt) -> BigUInt {
        max(totalIssuance / maxScore, BigUInt(1))
    }

    static func scoreOf(stake: BigUInt, given factor: BigUInt) -> Score {
        stake / factor
    }

    static func scoreOf(stake: BigUInt, totalIssuance: BigUInt) -> Score {
        let factor = scoreFactor(for: totalIssuance)
        return scoreOf(stake: stake, given: factor)
    }
}
