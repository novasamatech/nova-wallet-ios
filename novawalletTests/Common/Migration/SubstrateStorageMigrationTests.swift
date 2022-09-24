import XCTest
import RobinHood
import CoreData

@testable import novawallet

final class SubstrateStorageMigrationTests: XCTestCase {
    
    let databaseDirectoryURL = FileManager
        .default
        .temporaryDirectory
        .appendingPathComponent("CoreData")
        .appendingPathComponent("SubstrateStorageMigrationTests")
    
    let databaseName = SubstrateStorageParams.databaseName
    let modelDirectory = SubstrateStorageParams.modelDirectory
    var storeURL: URL { databaseDirectoryURL.appendingPathComponent(databaseName) }
    let mapper = ChainModelMapper()

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        try removeDirectory(at: databaseDirectoryURL)
        try FileManager.default.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        
        try removeDirectory(at: databaseDirectoryURL)
    }

    func testMigrationVersion1ToVersion2() {
        let timeout: TimeInterval = 5
        let generatedChains = generateChainsWithTimeout(timeout)
        XCTAssertGreaterThan(generatedChains.count, 0)
        
        let migrator = SubstrateStorageMigrator(storeURL: storeURL,
                                                modelDirectory: modelDirectory,
                                                model: .version2,
                                                fileManager: FileManager.default)
        
        XCTAssertTrue(migrator.requiresMigration(), "Migration is not required")
        
        let migrateExpectation = XCTestExpectation(description: "Migration expectation")
        migrator.migrate {
            migrateExpectation.fulfill()
        }
        
        wait(for: [migrateExpectation], timeout: timeout)
       
        let fetchedChains = fetchChainsWithTimeout(timeout)
        
        let sortedChainsBeforeMigration = generatedChains.sorted { $0.identifier < $1.identifier }
        let sortedChainsAfterMigration = fetchedChains.sorted { $0.identifier < $1.identifier }
        XCTAssertEqual(sortedChainsBeforeMigration, sortedChainsAfterMigration)
    }
    
    private func generateChainsWithTimeout(_ timeout: TimeInterval) -> [ChainModel] {
        var generatedChains: [ChainModel] = []
        let expectation = XCTestExpectation(description: "Generate chains expectation")
        
        generateChains { result in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            case .success(let chains):
                generatedChains = chains
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        return generatedChains
    }
    
    private func fetchChainsWithTimeout(_ timeout: TimeInterval) -> [ChainModel] {
        var fetchedChains: [ChainModel] = []
        let expectation = XCTestExpectation(description: "Fetch chains expectation")
        
        fetchChains { result in
            switch result {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            case .success(let chains):
                fetchedChains = chains
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        return fetchedChains
    }
    
    private func generateChains(completion: @escaping (Result<[ChainModel], Error>) -> Void) {
        let chains = ChainModelGenerator.generate(count: 5)
        let dbService = createCoreDataService(for: .version1)
        
        dbService.performAsync { [unowned self] (context, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let context = context else {
                completion(.failure(TestError.noCoreDataContext))
                return
            }
            
            do {
                try chains.forEach {
                    let insertedObject = NSEntityDescription.insertNewObject(forEntityName: "CDChain",
                                                                             into: context)
                    guard let newChain = insertedObject as? CDChain else {
                        throw TestError.unexpectedEntity
                    }
                    
                    try mapper.populate(entity: newChain,
                                        from: $0,
                                        using: context)
                    
                }
                
                try context.save()
                
                completion(.success(chains))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func fetchChains(completion: @escaping (Result<[ChainModel], Error>) -> Void) {
        let dbService = createCoreDataService(for: .version2)
        
        dbService.performAsync { [unowned self] (context, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let context = context else {
                completion(.failure(TestError.noCoreDataContext))
                return
            }
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "CDChain")
                guard let results = try context.fetch(request) as? [CDChain] else {
                    throw TestError.unexpectedEntity
                }
                let chains = try results.map(mapper.transform)
                completion(.success(chains))
            } catch {
                completion(.failure(error))
            }
        }
        
    }

    private func createCoreDataService(for version: SubstrateStorageVersion) -> CoreDataServiceProtocol {
        let modelURL = Bundle.main.url(
            forResource: version.rawValue,
            withExtension: "mom",
            subdirectory: modelDirectory
        )!

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: databaseDirectoryURL,
            databaseName: databaseName,
            incompatibleModelStrategy: .ignore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: persistentSettings)
        )

        return CoreDataService(configuration: configuration)
    }
    
    private func removeDirectory(at directoryURL: URL) throws {
        let fileManager = FileManager.default
        
        guard let tmpFiles = try? fileManager.contentsOfDirectory(at: directoryURL,
                                                                  includingPropertiesForKeys: nil,
                                                                  options: .skipsHiddenFiles) else {
            return
        }
        
        try tmpFiles.forEach(fileManager.removeItem)
        try fileManager.removeItem(at: directoryURL)
    }

}

// MARK: - Errors

extension SubstrateStorageMigrationTests {
    enum TestError: String, Error {
        case noCoreDataContext
        case unexpectedEntity
    }
}
