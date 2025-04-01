import Foundation
import SubstrateSdk

extension Xcm {
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
}
