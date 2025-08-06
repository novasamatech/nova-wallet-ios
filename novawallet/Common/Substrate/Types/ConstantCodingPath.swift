import Foundation

struct ConstantCodingPath {
    let moduleName: String
    let constantName: String
}

extension ConstantCodingPath {
    static var existentialDeposit: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Balances", constantName: "ExistentialDeposit")
    }

    static var paraLeasingPeriod: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Slots", constantName: "LeasePeriod")
    }

    static var paraLeasingOffset: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Slots", constantName: "LeaseOffset")
    }

    static var minimumPeriodBetweenBlocks: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Timestamp", constantName: "MinimumPeriod")
    }

    static var minimumContribution: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Crowdloan", constantName: "MinContribution")
    }

    static var electionsSessionPeriod: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Elections", constantName: "SessionPeriod")
    }

    static var azeroSessionPeriod: ConstantCodingPath {
        ConstantCodingPath(moduleName: "CommitteeManagement", constantName: "SessionPeriod")
    }
}
