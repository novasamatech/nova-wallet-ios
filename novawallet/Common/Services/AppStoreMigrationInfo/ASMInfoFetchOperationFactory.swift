import Foundation
import Operation_iOS

protocol ASMInfoFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<ASMRemoteData?>
}

final class ASMInfoFetchOperationFactory: BaseFetchOperationFactory {
    private let asmConfigPath: String

    init(asmConfigPath: String = ApplicationConfig.shared.appstoreMigrationConfigPath) {
        self.asmConfigPath = asmConfigPath
    }
}

// MARK: - Private

private extension ASMInfoFetchOperationFactory {
    func createURL() -> URL? {
        let path = NSString.path(withComponents: [Constants.configPath])
        let urlString = URL(string: asmConfigPath)?.appendingPathComponent(path)

        return urlString
    }
}

// MARK: - ASMInfoFetchOperationFactoryProtocol

extension ASMInfoFetchOperationFactory: ASMInfoFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<ASMRemoteData?> {
        guard let url = createURL() else { return .createWithError(NetworkBaseError.invalidUrl) }

        return createFetchOperation(from: url)
    }
}

// MARK: - Constants

private extension ASMInfoFetchOperationFactory {
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
