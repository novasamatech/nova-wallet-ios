import Foundation

struct DAppList: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case categories
        case dApps = "dapps"
    }

    let categories: [DAppCategory]
    let dApps: [DApp]
}

struct DApp: Codable, Equatable {
    let name: String
    let url: URL
    let icon: URL?
    let categories: [String]

    var identifier: String { url.absoluteString }
}

struct DAppCategory: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case name
    }

    let identifier: String
    let name: String
}
