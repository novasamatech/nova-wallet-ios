enum AssetListGroupModelComparator {
    static var byValue: (AssetListGroupModel, AssetListGroupModel) -> Bool? = {
        compare(model1: $0, model2: $1, by: \.chainValue, zeroValue: 0)
    }

    static var byTotalAmount: (AssetListGroupModel, AssetListGroupModel) -> Bool? = {
        compare(model1: $0, model2: $1, by: \.chainAmount, zeroValue: 0)
    }

    static func compare<T>(
        model1: AssetListGroupModel,
        model2: AssetListGroupModel,
        by keypath: KeyPath<AssetListGroupModel, T>,
        zeroValue: T
    ) -> Bool? where T: Comparable {
        if model1[keyPath: keypath] > zeroValue, model2[keyPath: keypath] > zeroValue {
            return model1[keyPath: keypath] > model2[keyPath: keypath]
        } else if model1[keyPath: keypath] > zeroValue {
            return true
        } else if model2[keyPath: keypath] > zeroValue {
            return false
        } else {
            return nil
        }
    }
}
