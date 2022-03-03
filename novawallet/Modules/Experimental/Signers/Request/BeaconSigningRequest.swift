import Foundation
import BeaconCore
import BeaconClientWallet
import BeaconBlockchainSubstrate

final class BeaconSigningRequest: SignerOperationRequestProtocol {
    let request: SignSubstrateRequest
    let client: Beacon.WalletClient
    let signingPayload: Data

    init(client: Beacon.WalletClient, request: SignSubstrateRequest) throws {
        self.request = request
        self.client = client
        signingPayload = try Data(hexString: request.payload)
    }

    func submit(signature: Data, completion closure: @escaping (Result<Void, Error>) -> Void) {
        do {
            let content = try ReturnSignSubstrateResponse(
                from: request,
                payload: signature.toHex(includePrefix: true)
            )

            let response = BeaconResponse<Substrate>.blockchain(
                .sign(SignSubstrateResponse.return(content))
            )

            client.respond(with: response) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        closure(.success(()))
                    case let .failure(error):
                        closure(.failure(error))
                    }
                }
            }
        } catch {
            let errorType = Beacon.ErrorType<Substrate>.aborted

            let remoteRequest = BlockchainSubstrateRequest.sign(request)

            let errorContent = ErrorBeaconResponse<Substrate>.init(
                from: remoteRequest,
                errorType: errorType,
                description: nil
            )

            let response = BeaconResponse<Substrate>.error(errorContent)
            client.respond(with: response, completion: { _ in })

            closure(.failure(error))
        }
    }
}
