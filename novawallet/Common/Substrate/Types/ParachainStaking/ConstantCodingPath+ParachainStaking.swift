import Foundation

extension ParachainStaking {
    static var maxTopDelegationsPerCandidate: ConstantCodingPath {
        ConstantCodingPath(
            moduleName: "ParachainStaking",
            constantName: "MaxTopDelegationsPerCandidate"
        )
    }

    static var minDelegatorStk: ConstantCodingPath {
        ConstantCodingPath(moduleName: "ParachainStaking", constantName: "MinDelegatorStk")
    }

    static var minDelegation: ConstantCodingPath {
        ConstantCodingPath(moduleName: "ParachainStaking", constantName: "MinDelegation")
    }

    static var delegationBondLessDelay: ConstantCodingPath {
        ConstantCodingPath(
            moduleName: "ParachainStaking",
            constantName: "DelegationBondLessDelay"
        )
    }

    static var blocksPerRound: ConstantCodingPath {
        ConstantCodingPath(moduleName: "ParachainStaking", constantName: "DefaultBlocksPerRound")
    }
}
