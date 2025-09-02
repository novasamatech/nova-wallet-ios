import Foundation
import Foundation_iOS

enum GovernanceDApps {
    struct DApp: Codable, Equatable {
        let title: String
        let details: String
        let urlV1: String?
        let urlV2: String?
        let icon: URL

        func extractFullUrl(for referendumIndex: ReferendumIdLocal, governanceType: GovernanceType) throws -> URL? {
            let urlTemplate: String?

            switch governanceType {
            case .governanceV1:
                urlTemplate = urlV1
            case .governanceV2:
                urlTemplate = urlV2
            }

            if let url = urlTemplate {
                return try URLBuilder(urlTemplate: url).buildParameterURL(String(referendumIndex))
            } else {
                return nil
            }
        }

        func supports(governanceType: GovernanceType) -> Bool {
            switch governanceType {
            case .governanceV1:
                return urlV1 != nil
            case .governanceV2:
                return urlV2 != nil
            }
        }
    }

    struct Item: Codable, Equatable {
        let chainId: String
        let dapps: [DApp]
    }
}

typealias GovernanceDAppList = [GovernanceDApps.Item]
