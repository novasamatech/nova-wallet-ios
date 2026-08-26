import Foundation
import Foundation_iOS

extension SwapSlippageViewFactory {
    static func createSubtensorView(
        percent: BigRational?,
        chainAsset: ChainAsset,
        completionHandler: @escaping (BigRational) -> Void
    ) -> SwapSlippageViewProtocol? {
        createView(
            percent: percent,
            chainAsset: chainAsset,
            config: SlippageConfig.subtensorStaking,
            completionHandler: completionHandler
        )
    }
}
