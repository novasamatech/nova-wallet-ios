import Foundation
import BeaconCore
import BeaconClientWallet
import BeaconBlockchainSubstrate

final class BeaconSigningRequest: SignerOperationRequestProtocol {
    let request: SignPayloadSubstrateRequest
    let client: Beacon.WalletClient
    let signingPayload: Data

    init(client: Beacon.WalletClient, request: SignPayloadSubstrateRequest) throws {
        self.request = request
        self.client = client

        switch request.payload {
        case let .json(json):
            signingPayload = Data()
        case let .raw(raw):
            signingPayload = try Data(hexString: raw.data)
        }
    }

    func submit(signature: Data, completion closure: @escaping (Result<Void, Error>) -> Void) {
        do {
            let content = try ReturnSignPayloadSubstrateResponse(
                from: request,
                signature: signature.toHex(includePrefix: true)
            )

            let response = BeaconResponse<Substrate>.blockchain(
                .signPayload(SignPayloadSubstrateResponse.return(content))
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

            let remoteRequest = BlockchainSubstrateRequest.signPayload(request)

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
