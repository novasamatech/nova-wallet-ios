import Foundation

struct SubtensorValidatorCoverage: Equatable {
    let permitted: Int
    let total: Int

    static func make(
        delegate: SubtensorPallet.DelegateInfo?,
        childNetuids: Set<UInt16> = [],
        catalogueNetuids: Set<UInt16>
    ) -> Self? {
        guard let delegate else { return nil }
        let permitted = Set(delegate.validatorPermits.map(\.value)).union(childNetuids).intersection(catalogueNetuids)
        return Self(permitted: permitted.count, total: catalogueNetuids.count)
    }
}
