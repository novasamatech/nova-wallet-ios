import Foundation

extension NovaAuth {
    func loadToken() throws -> NovaAuthTokenRecord? {
        if tokenCached { return tokenCache }
        do {
            tokenCache = try dependencies.tokenStore.load()
        } catch { throw NovaAuthError.storageUnavailable }
        tokenCached = true
        return tokenCache
    }

    func storeToken(_ record: NovaAuthTokenRecord) throws {
        tokenCached = false
        do {
            try dependencies.tokenStore.replace(record)
        } catch { throw NovaAuthError.storageUnavailable }
        tokenCache = record
        tokenCached = true
    }

    func removeAllTokens() throws {
        tokenCached = false
        do {
            try dependencies.tokenStore.removeAll()
        } catch { throw NovaAuthError.storageUnavailable }
        tokenCache = nil
        tokenCached = true
    }

    func removeRejectedOrInvalidToken(_ record: NovaAuthTokenRecord) throws {
        tokenCached = false
        do {
            let removed = try dependencies.tokenStore.remove(ifMatching: record)
            if !removed, try dependencies.tokenStore.load() == record {
                try dependencies.tokenStore.removeAll()
            }
        } catch { throw NovaAuthError.storageUnavailable }
    }
}
