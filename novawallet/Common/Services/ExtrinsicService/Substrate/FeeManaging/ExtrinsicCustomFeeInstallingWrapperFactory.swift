import Foundation
import Operation_iOS

protocol ExtrinsicCustomFeeInstallingFactoryProtocol {
    func createCustomFeeInstallerWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling>
}
