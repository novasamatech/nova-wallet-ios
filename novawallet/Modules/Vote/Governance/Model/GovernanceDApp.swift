import Foundation
import SoraFoundation

struct GovernanceDApp: Codable {
    struct Params: Codable {
        let network: String
        let index: ReferendumIdLocal
    }

    let name: String
    let subtitle: String
    let icon: URL
    let urlTemplate: String

    func url(for chain: ChainModel, referendumIndex: ReferendumIdLocal) throws -> URL {
        // TODO: move to chain.json to make to reliable
        let params = Params(
            network: chain.name.lowercased(),
            index: referendumIndex
        )

        return try EndpointBuilder(urlTemplate: urlTemplate).buildURL(with: params)
    }
}
