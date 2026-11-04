import Foundation

struct GlobalConfig {
    let multiStakingApiUrl: URL
    let multisigsApiUrl: URL
    let proxyApiUrl: URL
    let infraUrl: URL
    let changeNowTaoUrl: URL?
}

extension GlobalConfig: Decodable {
    private enum CodingKeys: String, CodingKey {
        case multiStakingApiUrl
        case multisigsApiUrl
        case proxyApiUrl
        case infraUrl
        case changeNowTaoUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        multiStakingApiUrl = try container.decode(URL.self, forKey: .multiStakingApiUrl)
        multisigsApiUrl = try container.decode(URL.self, forKey: .multisigsApiUrl)
        proxyApiUrl = try container.decode(URL.self, forKey: .proxyApiUrl)
        infraUrl = try container.decode(URL.self, forKey: .infraUrl)
        changeNowTaoUrl = try? container.decodeIfPresent(URL.self, forKey: .changeNowTaoUrl)
    }
}
