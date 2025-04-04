import Foundation

extension Xcm {
    struct Version4<W>: Equatable, Codable where W: Equatable & XcmUniCodable {
        let wrapped: W

        init(from decoder: any Decoder) throws {
            wrapped = try W(from: decoder, configuration: .V4)
        }

        func encode(to encoder: any Encoder) throws {
            try wrapped.encode(to: encoder, configuration: .V4)
        }
    }
}
