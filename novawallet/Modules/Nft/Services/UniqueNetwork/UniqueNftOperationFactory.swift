import Foundation
import SubstrateSdk
import Operation_iOS

protocol UniqueNftOperationFactoryProtocol {
    func fetchNfts(
        for address: AccountAddress,
        offset: Int,
        limit: Int
    ) -> CompoundOperationWrapper<UniqueScanNftResponse>
}

enum UniqueScanApi {
    static let mainnet = URL(string: "https://api-unique.uniquescan.io/v2")!
}

enum UniqueNftFactoryError: Error {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int)
    case noData
    case decodingError(Error)
}

final class UniqueNftOperationFactory: UniqueNftOperationFactoryProtocol {
    let base: URL

    init(apiBase: URL) {
        base = apiBase
    }

    func fetchNfts(
        for address: AccountAddress,
        offset: Int = 0,
        limit: Int = 1000
    ) -> CompoundOperationWrapper<UniqueScanNftResponse> {
        var comps = URLComponents(url: base.appendingPathComponent("nfts"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "topmostOwnerIn", value: address),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = comps.url else {
            let errorOperation = BaseOperation<UniqueScanNftResponse>()
            errorOperation.result = .failure(UniqueNftFactoryError.invalidURL)
            return CompoundOperationWrapper(targetOperation: errorOperation)
        }

        let urlRequest = URLRequest(url: url)

        let requestFactory = BlockNetworkRequestFactory {
            urlRequest
        }

        let resultFactory = AnyNetworkResultFactory<UniqueScanNftResponse> { data, response, error in
            if let networkError = error {
                if NetworkOperationHelper.isCancellation(error: networkError) {
                    return .failure(networkError)
                }
                return .failure(UniqueNftFactoryError.networkError(networkError))
            }

            if let httpResponse = response as? HTTPURLResponse, !(200 ... 299).contains(httpResponse.statusCode) {
                return .failure(UniqueNftFactoryError.httpError(statusCode: httpResponse.statusCode))
            }

            guard let responseData = data else {
                return .failure(UniqueNftFactoryError.noData)
            }

            do {
                let decoder = JSONDecoder()
                let parsedResponse = try decoder.decode(UniqueScanNftResponse.self, from: responseData)
                return .success(parsedResponse)
            } catch let decodingError {
                return .failure(UniqueNftFactoryError.decodingError(decodingError))
            }
        }

        let networkOperation = NetworkOperation<UniqueScanNftResponse>(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return CompoundOperationWrapper(targetOperation: networkOperation)
    }
}
