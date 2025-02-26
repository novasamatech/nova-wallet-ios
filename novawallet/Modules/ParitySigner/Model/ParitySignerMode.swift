import Foundation
import SubstrateSdk

enum ParitySignerSigningMode {
    struct Extrinsic {
        let extrinsicMemo: ExtrinsicBuilderMemoProtocol
        let codingFactory: RuntimeCoderFactoryProtocol
    }

    case extrinsic(Extrinsic)
    case rawBytes
}
