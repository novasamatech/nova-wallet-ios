import Foundation
import SubstrateSdk

extension XcmV4 {
    typealias Junctions = Xcm.GenericJunctions<XcmV4.Junction>
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
