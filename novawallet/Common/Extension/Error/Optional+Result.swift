import Foundation

extension Optional {
    func hasError<TData, TError: Error>() -> Bool where Wrapped == Result<TData, TError> {
        switch self {
        case .success, .none:
            return false
        case .failure:
            return true
        }
    }

    func mapOrThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else {
            throw error
        }

        return value
    }
}
