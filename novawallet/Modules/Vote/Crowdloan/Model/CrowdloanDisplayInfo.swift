import Foundation

struct CrowdloanDisplayInfo: Codable, Equatable {
    let paraid: String
    let name: String
    let token: String
    let description: String
    let website: String
    let icon: String
    let rewardRate: Decimal?
    let customFlow: String?
    let extras: [String: String]?
    let movedToParaId: String?
}

typealias CrowdloanDisplayInfoList = [CrowdloanDisplayInfo]
typealias CrowdloanDisplayInfoDict = [ParaId: CrowdloanDisplayInfo]

extension CrowdloanDisplayInfoList {
    func toMap() -> CrowdloanDisplayInfoDict {
        reduce(into: CrowdloanDisplayInfoDict()) { dict, info in
            guard let paraId = ParaId(info.paraid) else {
                return
            }

            dict[paraId] = info
        }
    }
}

extension CrowdloanDisplayInfo {
    var chainId: String? {
        extras?["paraId"]
    }
}
