import Foundation
import SubstrateSdk

protocol SignerOperationRequestProtocol {
    var signingPayload: Data { get }

    func submit(signature: Data, completion closure: @escaping (Result<Void, Error>) -> Void)
}
