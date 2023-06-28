import Foundation

class AssetListBuilder {
    let workingQueue: DispatchQueue
    let callbackQueue: DispatchQueue
    let resultClosure: (AssetListBuilderResult) -> Void

    init(
        workingQueue: DispatchQueue = .init(label: "com.nova.wallet.assets.builder", qos: .userInteractive),
        callbackQueue: DispatchQueue = .main,
        resultClosure: @escaping (AssetListBuilderResult) -> Void
    ) {
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.resultClosure = resultClosure
    }
}
