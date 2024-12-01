import Foundation
import Operation_iOS

protocol ExtrinsicFeeInstallingWrapperFactoryProtocol {
    func createNativeFeeInstallerWrapper(
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling>

    func createCustomFeeInstallerWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling>
}

final class ExtrinsicFeeInstallingWrapperFactory {
    let customFeeInstallerFactory: ExtrinsicCustomFeeInstallingFactoryProtocol

    init(customFeeInstallerFactory: ExtrinsicCustomFeeInstallingFactoryProtocol) {
        self.customFeeInstallerFactory = customFeeInstallerFactory
    }
}

extension ExtrinsicFeeInstallingWrapperFactory: ExtrinsicFeeInstallingWrapperFactoryProtocol {
    func createNativeFeeInstallerWrapper(
        accountClosure _: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        CompoundOperationWrapper.createWithResult(ExtrinsicNativeFeeInstaller())
    }

    func createCustomFeeInstallerWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        customFeeInstallerFactory.createCustomFeeInstallerWrapper(
            chainAsset: chainAsset,
            accountClosure: accountClosure
        )
    }
}
