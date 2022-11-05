import Foundation

extension Democracy {
    static var votingPeriod: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Democracy", constantName: "VotingPeriod")
    }

    static var enactmentPeriod: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Democracy", constantName: "EnactmentPeriod")
    }
}
