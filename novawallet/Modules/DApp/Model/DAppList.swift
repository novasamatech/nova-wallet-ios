import Foundation

struct DAppList: Codable, Equatable {
    let categories: [DAppCategory]
    let dApps: [DApp]
}

struct DApp: Codable, Equatable {
    let name: String
    let url: URL
    let icon: URL?
    let categories: [String]
}

struct DAppCategory: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case name
    }

    let identifier: String
    let name: String
}
