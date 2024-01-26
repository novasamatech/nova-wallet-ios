import Foundation

extension ConvictionVoting {
    static var voteLockingPeriodPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "VoteLockingPeriod")
    }

    static var maxVotes: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "MaxVotes")
    }
}
