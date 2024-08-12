import Foundation
import SubstrateSdk

protocol ExtrinsicFeeInstalling {
    func installingFeeSettings(
        to builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol
}
