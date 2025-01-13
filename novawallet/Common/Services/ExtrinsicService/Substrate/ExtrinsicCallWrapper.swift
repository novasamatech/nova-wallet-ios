import Foundation
import SubstrateSdk

protocol ExtrinsicCallWrapping {
    func adding(to builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol
    func getJsonArgsCall() throws -> RuntimeCall<JSON>
}
