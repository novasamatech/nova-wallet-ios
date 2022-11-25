import Foundation
import SoraFoundation

enum GovernanceDApps {
    struct DApp: Codable, Equatable {
        let title: String
        let details: String
        let url: String
        let icon: URL

        func extractFullUrl(for referendumIndex: ReferendumIdLocal) throws -> URL {
            try EndpointBuilder(urlTemplate: url).buildParameterURL(String(referendumIndex))
        }
    }

    struct Item: Codable, Equatable {
        let chainId: String
        let dapps: [DApp]
    }
}

typealias GovernanceDAppList = [GovernanceDApps.Item]
