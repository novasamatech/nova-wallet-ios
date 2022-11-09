import Foundation
import RobinHood

struct ReferendumMetadataPreview: Equatable {
    let chainId: String
    let referendumId: ReferendumIdLocal
    let title: String?
}

struct ReferendumMetadataLocal: Equatable {
    struct TimelineItem: Equatable, Codable {
        let block: BlockNumber
        let status: String
    }

    let chainId: String
    let referendumId: ReferendumIdLocal
    let title: String?
    let content: String?
    let proposer: String?
    let timeline: [TimelineItem]?

    func proposerAccountId(for chainFormat: ChainFormat) -> AccountId? {
        try? proposer?.toAccountId(using: chainFormat)
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

extension ReferendumMetadataPreview: Identifiable {
    var identifier: String {
        ReferendumMetadataLocal.identifier(from: chainId, referendumId: referendumId)
    }
}
