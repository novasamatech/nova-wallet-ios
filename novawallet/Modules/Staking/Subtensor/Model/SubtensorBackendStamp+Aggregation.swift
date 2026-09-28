import Foundation

extension SubtensorBackendStamp {
    init(component: BittensorApi.AvailableComponent, isFromExpiredCache: Bool) {
        let isStale = isFromExpiredCache || component.freshness == .stale

        self.init(asOf: component.asOf, freshness: isStale ? .stale : .fresh)
    }

    init?(metadata: BittensorApi.ComponentMetadata, isFromExpiredCache: Bool) {
        guard case let .available(component) = metadata else {
            return nil
        }

        self.init(component: component, isFromExpiredCache: isFromExpiredCache)
    }

    static func aggregate(_ stamps: [SubtensorBackendStamp]) -> SubtensorBackendStamp? {
        guard let oldest = stamps.min(by: { $0.asOf < $1.asOf }) else {
            return nil
        }

        let isStale = stamps.contains { $0.freshness == .stale }

        return SubtensorBackendStamp(asOf: oldest.asOf, freshness: isStale ? .stale : .fresh)
    }
}
