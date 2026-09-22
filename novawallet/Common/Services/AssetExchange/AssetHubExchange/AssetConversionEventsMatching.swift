import Foundation

final class AssetConversionEventsMatching: ExtrinsicEventsMatching {
    let paths: Set<EventCodingPath>

    init(commissionStorageInfo: AssetStorageInfo? = nil) {
        var paths = [AssetConversionPallet.swapExecutedEvent, BalancesPallet.balancesTransfer]
        if case let .statemine(info) = commissionStorageInfo {
            paths.append(PalletAssets.transferredPath(for: info.palletName))
        }
        self.paths = Set(paths)
    }

    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(event, oneOf: paths)
    }
}
