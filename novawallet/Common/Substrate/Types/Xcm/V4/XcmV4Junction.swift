import Foundation
import SubstrateSdk

extension XcmV4 {
    struct GenericJunctions<J>: Codable, Equatable where J: Codable & Equatable {
        let items: [J]

        init(items: [J]) {
            self.items = items
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            if type == Xcm.JunctionsConstants.hereField {
                items = []
            } else {
                items = try container.decode([J].self)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            if items.isEmpty {
                try container.encode(Xcm.JunctionsConstants.hereField)
            } else {
                let xLocation = "\(Xcm.JunctionsConstants.junctionPrefix)\(items.count)"
                try container.encode(xLocation)
            }

            if items.isEmpty {
                try container.encode(JSON.null)
            } else {
                try container.encode(items)
            }
        }
    }

    typealias Junctions = GenericJunctions<XcmV4.Junction>
}

extension XcmV4.Junctions {
    func appending(components: [XcmV4.Junction]) -> XcmV4.Junctions {
        XcmV4.Junctions(items: items + components)
    }

    func prepending(components: [XcmV4.Junction]) -> XcmV4.Junctions {
        XcmV4.Junctions(items: components + items)
    }

    func lastComponent() -> (XcmV4.Junctions, XcmV4.Junctions) {
        guard let lastJunction = items.last else {
            return (self, XcmV4.Junctions(items: []))
        }

        let remaningItems = Array(items.dropLast())

        return (XcmV4.Junctions(items: remaningItems), XcmV4.Junctions(items: [lastJunction]))
    }
}
