import Foundation

struct DAppList: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case popular
        case categories
        case dApps = "dapps"
    }

    let popular: [DAppPopular]
    let categories: [DAppCategory]
    let dApps: [DApp]
}

struct DAppPopular: Codable, Equatable {
    let url: URL
}

struct DApp: Codable, Equatable {
    let name: String
    let url: URL
    let icon: URL?
    let categories: [String]
    let desktopOnly: Bool?
    var identifier: String { url.absoluteString }
}

struct DAppCategory: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case icon
        case name
    }

    let identifier: String
    let icon: URL?
    let name: String
}

enum KnownDAppCategory: String {
    case staking
}
