import Foundation

struct RaiseResponseContent<A: Decodable>: Decodable {
    enum CodingKeys: String, CodingKey {
        case type
        case identifier = "id"
        case attributes
    }

    let type: String
    let identifier: String
    let attributes: A
}

struct RaiseResponse<A: Decodable>: Decodable {
    let data: RaiseResponseContent<A>
}

struct RaiseListMeta: Decodable {
    enum CodingKeys: String, CodingKey {
        case total = "total_count"
    }

    let total: Int
}

struct RaiseListResponse<A: Decodable>: Decodable {
    enum CodingKeys: String, CodingKey {
        case data
        case meta
    }

    let data: [RaiseResponseContent<A>]
    let meta: RaiseListMeta?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meta = try container.decodeIfPresent(RaiseListMeta.self, forKey: .meta)

        var arrayContainer = try container.nestedUnkeyedContainer(forKey: .data)
        var content: [RaiseResponseContent<A>] = []
        while !arrayContainer.isAtEnd {
            do {
                let element = try arrayContainer.decode(RaiseResponseContent<A>.self)
                content.append(element)
            } catch {
                // If decoding fails, skip this element by decoding into a placeholder
                // UnkeyedDecodingContainer increments currentIndex after every successful decode call
                _ = try? arrayContainer.decode(AnyDecodable.self)
            }
        }

        data = content
    }

    // Workaround to skip invalid elements
    private struct AnyDecodable: Decodable {}
}
