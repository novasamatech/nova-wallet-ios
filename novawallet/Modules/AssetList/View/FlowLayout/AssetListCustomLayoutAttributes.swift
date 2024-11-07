import UIKit

struct AssetListTokenSectionState {
    let expandable: Bool
    let expanded: Bool
    let index: Int

    func byChanging(
        expandable: Bool? = nil,
        expanded: Bool? = nil,
        _ index: Int? = nil
    ) -> Self {
        .init(
            expandable: expandable ?? self.expandable,
            expanded: expanded ?? self.expanded,
            index: index ?? self.index
        )
    }
}

extension [String: AssetListTokenSectionState] {
    mutating func changeState(
        with key: String,
        closure: (Value) -> Value
    ) {
        if let value = self[key] {
            self[key] = closure(value)
        } else {
            self[key] = closure(
                AssetListTokenSectionState(
                    expandable: false,
                    expanded: false,
                    index: 0
                )
            )
        }
    }
}

class AssetListCustomLayoutAttributes: UICollectionViewLayoutAttributes {
    var isExpanded: Bool = false

    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone)
        let assetListAttributes = copy as? AssetListCustomLayoutAttributes

        assetListAttributes?.isExpanded = isExpanded

        return assetListAttributes ?? copy
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? AssetListCustomLayoutAttributes else {
            return false
        }
        return other.isExpanded == isExpanded && super.isEqual(object)
    }
}
