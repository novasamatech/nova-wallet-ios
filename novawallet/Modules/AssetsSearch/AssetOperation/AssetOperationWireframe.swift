class AssetOperationWireframe {
    private(set) var stateObservable: AssetListModelObservable

    init(stateObservable: AssetListModelObservable) {
        self.stateObservable = stateObservable
    }
}
