import Foundation
import Operation_iOS

final class LegalDocumentsFetchOperationFactory: BaseFetchOperationFactory {
    private let legalDocumentsPath: String

    init(legalDocumentsPath: String = ApplicationConfig.shared.legalDocumentsPath) {
        self.legalDocumentsPath = legalDocumentsPath
    }
}

// MARK: - Private

private extension LegalDocumentsFetchOperationFactory {
    func createURL() -> URL? {
        URL(string: legalDocumentsPath)?.appendingPathComponent(Constants.configPath)
    }
}

// MARK: - LegalDocumentsFetchOperationFactoryProtocol

extension LegalDocumentsFetchOperationFactory: LegalDocumentsFetchOperationFactoryProtocol {
    func fetchOperation() -> BaseOperation<LegalDocumentsRemote> {
        guard let url = createURL() else { return .createWithError(NetworkBaseError.invalidUrl) }

        return createFetchOperation(
            from: url,
            shouldUseCache: false,
            timeout: Constants.timeout
        )
    }
}

// MARK: - Constants

private extension LegalDocumentsFetchOperationFactory {
    enum Constants {
        static let timeout: TimeInterval = 10

        static var configPath: String {
            #if F_RELEASE
                "documents.json"
            #else
                "documents_dev.json"
            #endif
        }
    }
}
