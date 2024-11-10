import Foundation
import Operation_iOS

final class SendAssetOperationNetworkListInteractor: AssetOperationNetworkListInteractor {
    override func createModelBuilder(
        with chainAssets: [ChainAsset],
        resultClosure: @escaping (AssetOperationNetworkBuilderResult?) -> Void
    ) -> AssetOperationNetworkBuilder {
        SendAssetOperationNetworkBuilder(
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
