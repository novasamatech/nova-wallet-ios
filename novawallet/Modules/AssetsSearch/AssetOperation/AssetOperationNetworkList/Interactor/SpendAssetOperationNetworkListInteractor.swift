import Foundation
import Operation_iOS

final class SpendAssetOperationNetworkListInteractor: AssetOperationNetworkListInteractor {
    override func createModelBuilder(
        with chainAssets: [ChainAsset],
        resultClosure: @escaping (AssetOperationNetworkBuilderResult?) -> Void
    ) -> AssetOperationNetworkBuilder {
        SpendAssetOperationNetworkBuilder(
            chainAssets: chainAssets,
            workingQueue: .init(
                label: workingQueueLabel,
                qos: .userInteractive
            ),
            callbackQueue: .main,
            callbackClosure: resultClosure,
            logger: logger
        )
    }
}
