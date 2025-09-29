import Foundation
import Operation_iOS

protocol AHMInfoFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<[AHMRemoteData]>
}

final class AHMInfoFetchOperationFactory: BaseFetchOperationFactory {
    private let ahmConfigsPath: String

    init(ahmConfigsPath: String = ApplicationConfig.shared.assetHubMigrationConfigsPath) {
        self.ahmConfigsPath = ahmConfigsPath
    }
}

// MARK: - Private

private extension AHMInfoFetchOperationFactory {
    func createURL() -> URL? {
        let path = NSString.path(withComponents: [Constants.configPath])
        let urlString = URL(string: ahmConfigsPath)?.appendingPathComponent(path)

        return urlString
    }
}

// MARK: - AHMInfoFetchOperationFactoryProtocol

extension AHMInfoFetchOperationFactory: AHMInfoFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<[AHMRemoteData]> {
        guard let url = createURL() else { return .createWithError(NetworkBaseError.invalidUrl) }

        return createFetchOperation(from: url)
    }
}

// MARK: - Constants

private extension AHMInfoFetchOperationFactory {
    enum Constants {
        static var configPath: String {
            #if F_RELEASE
                "migrations.json"
            #else
                "migrations_dev.json"
            #endif
        }
    }
}
