import Foundation

extension NovaAuth {
    func loadToken() throws -> NovaAuthTokenRecord? {
        if let tokenCache { return tokenCache }
        do {
            tokenCache = try dependencies.tokenStore.load()
        } catch { throw NovaAuthError.storageUnavailable }
        return tokenCache
    }

    func storeToken(_ record: NovaAuthTokenRecord) throws {
        tokenCache = nil
        do {
            try dependencies.tokenStore.replace(record)
        } catch { throw NovaAuthError.storageUnavailable }
        tokenCache = record
    }

    func removeAllTokens() throws {
        tokenCache = nil
        do {
            try dependencies.tokenStore.removeAll()
        } catch { throw NovaAuthError.storageUnavailable }
    }

    func removeRejectedOrInvalidToken(_ record: NovaAuthTokenRecord) throws {
        tokenCache = nil
        do {
            let removed = try dependencies.tokenStore.remove(ifMatching: record)
            if !removed, try dependencies.tokenStore.load() == record {
                try dependencies.tokenStore.removeAll()
            }
        } catch { throw NovaAuthError.storageUnavailable }
    }
}
