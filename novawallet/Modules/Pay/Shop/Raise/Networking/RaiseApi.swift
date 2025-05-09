import Foundation
import Operation_iOS

enum RaiseApi {
    #if F_RELEASE
        static let baseUrl = URL(string: "https://commerce-api.raise.com/business/v2/")!
    #else
        static let baseUrl = URL(string: "https://sandbox-commerce-api.raise.com/business/v2/")!
    #endif

    case createAuthentication(Data)
    case generateNonce
    case validateVerification(Data)
    case refreshToken

    case brandList(RaiseBrandsRequestInfo)
    case brands([String])
    case cards
    case transactionCreate(RaiseTransactionCreateAttributes)
    case transactionUpdate(String, RaiseTransactionUpdateAttributes)
    case transaction(String)
    case cryptoAssets
    case rate(from: AssetModel, toCurrency: Currency)
}

extension RaiseApi: URLConvertible {
    var url: URL {
        var components = URLComponents(string: urlString)
        components?.queryItems = queryItems
        guard let url = components?.url(relativeTo: Self.baseUrl) else {
            assertionFailure()
            return Self.baseUrl
        }
        return url
    }

    var httpMethod: String {
        switch self {
        case .brandList:
            HttpMethod.get.rawValue
        case .brands:
            HttpMethod.get.rawValue
        case .cards:
            HttpMethod.get.rawValue
        case .transactionCreate:
            HttpMethod.post.rawValue
        case .transactionUpdate:
            "PATCH"
        case .transaction:
            HttpMethod.get.rawValue
        case .cryptoAssets:
            HttpMethod.get.rawValue
        case .createAuthentication:
            HttpMethod.post.rawValue
        case .generateNonce:
            HttpMethod.post.rawValue
        case .validateVerification:
            HttpMethod.post.rawValue
        case .refreshToken:
            HttpMethod.post.rawValue
        case .rate:
            HttpMethod.post.rawValue
        }
    }

    private var urlString: String {
        switch self {
        case .brandList:
            "brands"
        case .brands:
            "brands"
        case .cards:
            "cards"
        case .transactionCreate:
            "transactions"
        case let .transactionUpdate(id, _):
            "transactions/\(id)"
        case let .transaction(id):
            "transactions/\(id)"
        case .cryptoAssets:
            "crypto_assets"
        case .createAuthentication:
            "auth/methods"
        case .generateNonce,
             .validateVerification,
             .refreshToken:
            "auth/tokens"
        case .rate:
            "crypto_quotes"
        }
    }

    private var queryItems: [URLQueryItem]? {
        switch self {
        case let .brandList(params):
            var query = [
                URLQueryItem(name: "page[number]", value: "\(params.pageIndex)"),
                URLQueryItem(name: "page[size]", value: "\(params.pageSize)")
            ]
            if let value = params.query.map({ URLQueryItem(name: "query", value: $0) }) {
                query.append(value)
            }

            return query
        case let .brands(ids):
            let query = URLQueryItem(name: "ids", value: ids.joined(separator: ","))
            return [query]
        case .cards:
            let query = [
                URLQueryItem(name: "page[size]", value: "500"),
                URLQueryItem(name: "state", value: "ACTIVE"),
                URLQueryItem(name: "sort_by", value: "created_at"),
                URLQueryItem(name: "sort", value: "DESC")
            ]
            return query
        default:
            return nil
        }
    }

    var params: Encodable? {
        switch self {
        case .brandList:
            nil
        case .brands:
            nil
        case .cards:
            nil
        case let .transactionCreate(data):
            RaiseRequest(
                data: .init(
                    type: "transactions",
                    attributes: data
                )
            )
        case let .transactionUpdate(id, data):
            RaiseIdentifiableRequest(
                data: .init(
                    identifier: id,
                    type: "transactions",
                    attributes: data
                )
            )
        case .transaction:
            nil
        case .cryptoAssets:
            nil
        case let .createAuthentication(publicKey):
            RaiseRequest(
                data: .init(
                    type: "auth/methods",
                    attributes: RaiseNonceRequest(
                        type: "SR25519_KEY_PAIR",
                        publicKey: publicKey
                    )
                )
            )
        case .generateNonce:
            RaiseRequest(
                data: .init(
                    type: "auth/tokens",
                    attributes: RaiseActionRequest(action: "GENERATE_NONCE")
                )
            )
        case let .validateVerification(data):
            RaiseRequest(
                data: .init(
                    type: "auth/tokens",
                    attributes: RaiseVerificationRequest(
                        action: "VALIDATE_VERIFICATION",
                        signedNonce: data
                    )
                )
            )
        case .refreshToken:
            RaiseRequest(
                data: .init(
                    type: "auth/tokens",
                    attributes: RaiseActionRequest(
                        action: "REFRESH"
                    )
                )
            )
        case let .rate(asset, currency):
            RaiseRequest(
                data: .init(
                    type: "crypto_quotes",
                    attributes: RaiseCryptoQuoteRequest(
                        from: asset.symbol,
                        to: currency.code
                    )
                )
            )
        }
    }
}
