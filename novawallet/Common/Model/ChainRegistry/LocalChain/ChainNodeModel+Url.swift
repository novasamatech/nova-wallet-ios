import Foundation

extension ChainNodeModel {
    func getUrl() -> URL? {
        let builder = URLBuilder(urlTemplate: url)

        guard let url = try? builder.buildBy(closure: { apiKeyType in
            guard let apiKey = ConnectionApiKeys.getKey(by: apiKeyType) else {
                throw CommonError.undefined
            }

            return apiKey
        }) else {
            return nil
        }

        return url
    }
}
