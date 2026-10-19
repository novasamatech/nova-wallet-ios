import Foundation

struct SubtensorValidatorCoverage: Equatable {
    let permitted: Int
    let total: Int

    static func make(
        hotkey: AccountId,
        delegates: [SubtensorPallet.DelegateInfo],
        catalogueNetuids: Set<UInt16>
    ) -> Self? {
        let matches = delegates.filter { $0.delegateSs58 == hotkey }
        guard matches.count == 1, let delegate = matches.first else { return nil }
        let permitted = Set(delegate.validatorPermits.map(\.value)).intersection(catalogueNetuids)
        return Self(permitted: permitted.count, total: catalogueNetuids.count)
    }
}
