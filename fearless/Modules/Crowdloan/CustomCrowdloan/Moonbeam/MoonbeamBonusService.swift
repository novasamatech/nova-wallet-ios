import Foundation
import RobinHood
import BigInt
import IrohaCrypto
import FearlessUtils

final class MoonbeamBonusService {
    #if DEBUG
        static let baseURL = URL(string: "https://wallet-test.api.purestake.xyz")!
    #endif

    static let apiHealth = "/health"

    let address: AccountAddress
    let operationManager: OperationManagerProtocol
    private let requestModifier = MoonbeamRequestModifier()

    init(
        address: AccountAddress,
        operationManager: OperationManagerProtocol
    ) {
        self.address = address
        self.operationManager = operationManager
    }

    func createCheckHealthOperation() -> BaseOperation<Void> {
        let url = Self.baseURL.appendingPathComponent(Self.apiHealth)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Void> { _ in
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }
}

private class MoonbeamRequestModifier: NetworkRequestModifierProtocol {
    #if DEBUG
        static let apiKey = "4klO0S7XEI5I2eAkWLoSH6thDH5FuRbb6tpR7PqU"
    #endif

    func modify(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.addValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        return modifiedRequest
    }
}
