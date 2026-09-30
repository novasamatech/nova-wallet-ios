import Foundation

struct SubtensorSubnetLogos {
    let urls: [UInt16: URL]

    func url(for netuid: UInt16) -> URL? {
        urls[netuid]
    }
}

extension SubtensorSubnetLogos: Decodable {
    private enum CodingKeys: String, CodingKey {
        case subnets
    }

    private struct Entry: Decodable {
        private enum CodingKeys: String, CodingKey {
            case netuid
            case logo
        }

        let netuid: UInt16?
        let logo: URL?

        init(from decoder: Decoder) throws {
            let container = try? decoder.container(keyedBy: CodingKeys.self)

            netuid = try? container?.decode(UInt16.self, forKey: .netuid)
            logo = (try? container?.decode(String.self, forKey: .logo)).flatMap(Self.httpsUrl(from:))
        }

        private static func httpsUrl(from value: String) -> URL? {
            guard
                let url = URL(string: value),
                url.scheme?.lowercased() == "https",
                url.host != nil else {
                return nil
            }

            return url
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([Entry].self, forKey: .subnets)

        let logos = entries.compactMap { entry -> (UInt16, URL)? in
            guard let netuid = entry.netuid, let logo = entry.logo else {
                return nil
            }

            return (netuid, logo)
        }

        self.init(urls: Dictionary(logos, uniquingKeysWith: { first, _ in first }))
    }
}
