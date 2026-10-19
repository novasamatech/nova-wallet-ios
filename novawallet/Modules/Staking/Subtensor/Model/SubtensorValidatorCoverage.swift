import Foundation

struct SubtensorValidatorCoverage: Equatable {
    let permitted: Int
    let total: Int

    static func make(
        delegate: SubtensorPallet.DelegateInfo?,
        catalogueNetuids: Set<UInt16>
    ) -> Self? {
        guard let delegate else { return nil }
        let permitted = Set(delegate.validatorPermits.map(\.value)).intersection(catalogueNetuids)
        return Self(permitted: permitted.count, total: catalogueNetuids.count)
    }
}
