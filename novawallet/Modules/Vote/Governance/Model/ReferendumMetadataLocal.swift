import Foundation
import RobinHood

struct ReferendumMetadataPreview: Equatable {
    let chainId: String
    let referendumId: ReferendumIdLocal
    let title: String?
}

enum ReferendumMetadataStatus: String {
    case started = "Started"
    case passed = "Passed"
    case notPassed = "NotPassed"
    case executed = "Executed"
}

enum ReferendumMetadataStatusV2: String {
    case ongoing = "Ongoing"
    case approved = "Approved"
    case rejected = "Rejected"
    case cancelled = "Cancelled"
    case timedOut = "TimedOut"
    case killed = "Killed"
}

struct ReferendumMetadataLocal: Equatable {
    struct TimelineItem: Equatable, Codable {
        let time: Date
        let status: String
    }

    let chainId: String
    let referendumId: ReferendumIdLocal
    let title: String?
    let content: String?
    let proposer: String?
    let timeline: [TimelineItem]?

    func proposerAccountId(for chainFormat: ChainFormat) -> AccountId? {
        if let chainAccountId = try? proposer?.toAccountId(using: chainFormat) {
            return chainAccountId
        } else {
            return try? proposer?.toAccountId()
        }
    }
}

extension ReferendumMetadataLocal: Identifiable {
    static func identifier(from chainId: ChainModel.Id, referendumId: ReferendumIdLocal) -> String {
        chainId + "-" + String(referendumId)
    }

    var identifier: String {
        Self.identifier(from: chainId, referendumId: referendumId)
    }
}

extension ReferendumMetadataLocal.TimelineItem {
    var isStarted: Bool {
        status == ReferendumMetadataStatus.started.rawValue ||
            status == ReferendumMetadataStatusV2.ongoing.rawValue
    }

    var isApproved: Bool {
        status == ReferendumMetadataStatus.passed.rawValue ||
            status == ReferendumMetadataStatusV2.approved.rawValue
    }

    var isExecuted: Bool {
        status == ReferendumMetadataStatus.executed.rawValue
    }
}

extension ReferendumMetadataPreview: Identifiable {
    var identifier: String {
        ReferendumMetadataLocal.identifier(from: chainId, referendumId: referendumId)
    }
}
