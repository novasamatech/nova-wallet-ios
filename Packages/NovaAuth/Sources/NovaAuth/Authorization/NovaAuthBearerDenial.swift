import Foundation

enum NovaAuthBearerDenial {
    static func isInvalidToken(_ response: NovaAuthResponse, request: NovaAuthRequest) -> Bool {
        guard response.response.statusCode == 401, let url = response.response.url,
              url.scheme == "https", url.host == request.context.origin.url.host,
              url.port == request.context.origin.url.port,
              url.user == nil, url.password == nil else { return false }
        let headers = response.response.allHeaderFields.filter {
            String(describing: $0.key).lowercased() == "www-authenticate"
        }
        guard headers.count == 1, let header = headers.first?.value as? String,
              header == "Bearer error=\"invalid_token\"" else { return false }
        return NovaAuthWire.errorCode(from: response.body) == "invalid_token"
    }
}
