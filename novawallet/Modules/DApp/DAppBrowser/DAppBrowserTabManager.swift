import Foundation
import Operation_iOS

struct DAppBrowserTab {
    let uuid: UUID
    let name: String?
    let url: URL
    let lastModified: TimeInterval
    let opaqueState: [Any]?
    let stateRender: Data?
    let icon: URL?
    
    var persistenceModel: PersistenceModel {
        PersistenceModel(
            uuid: uuid,
            name: name,
            url: url,
            lastModified: lastModified,
            icon: icon
        )
    }
    
    func updating(
        state: Any? = nil,
        name: String? = nil,
        url: URL? = nil,
        lastModified: TimeInterval? = nil,
        stateRender: Data? = nil,
        icon: URL? = nil
    ) -> Self {
        .init(
            uuid: uuid,
            name: name ?? self.name,
            url: url ?? self.url,
            lastModified: lastModified ?? self.lastModified,
            opaqueState: state ?? self.opaqueState,
            stateRender: stateRender ?? self.stateRender,
            icon: icon ?? self.icon
        )
    }
}

extension DAppBrowserTab {
    struct PersistenceModel: Hashable, Equatable, Identifiable {
        var identifier: String { uuid.uuidString }
        
        let uuid: UUID
        let name: String?
        let url: URL
        let lastModified: TimeInterval
        let icon: URL?
    }
}

protocol DAppBrowserTabManagerProtocol {
    func createTab(for dApp: DApp) -> BaseOperation<DAppBrowserTab>
    func retrieveTab(with id: UUID) -> BaseOperation<DAppBrowserTab?>
    func getAllTabs() -> BaseOperation<[DAppBrowserTab]>
    
    @discardableResult
    func updateTab(_ tab: DAppBrowserTab) -> BaseOperation<DAppBrowserTab>
    
    func removeTab(with id: UUID)
}

final class DAppBrowserTabManager {
    private let cacheBasePath: String
    private let repository: CoreDataRepository<DAppBrowserTab.PersistenceModel, CDDAppBrowserTab>
    private let operationQueue: OperationQueue
    
    private var dAppTransportStates: [UUID: [Any]] = [:]
    private var tabs: [UUID: DAppBrowserTab] = [:]
    
    init(
        cacheBasePath: String,
        repository: CoreDataRepository<DAppBrowserTab.PersistenceModel, CDDAppBrowserTab>,
        operationQueue: OperationQueue
    ) {
        self.cacheBasePath = cacheBasePath
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

// MARK: DAppBrowserTabManagerProtocol

extension DAppBrowserTabManager: DAppBrowserTabManagerProtocol {
    func retrieveTab(with id: UUID) -> BaseOperation<DAppBrowserTab?> {
        if let currentTab = tabs[id] {
            return .createWithResult(currentTab)
        } else {
            let fetchOperation = repository.fetchOperation(
                by: { id.uuidString },
                options: RepositoryFetchOptions()
            )
            
            let resultOperation = ClosureOperation<DAppBrowserTab?> { [weak self] in
                guard let fetchResult = try fetchOperation.extractNoCancellableResultData() else {
                    return nil
                }
                
                let tab = DAppBrowserTab(
                    uuid: fetchResult.uuid,
                    name: fetchResult.name,
                    url: fetchResult.url,
                    lastModified: fetchResult.lastModified,
                    opaqueState: self?.dAppTransportStates[fetchResult.uuid],
                    stateRender: nil,
                    icon: fetchResult.icon
                )
                
                self?.tabs[tab.uuid] = tab
                
                return tab
            }
            
            return resultOperation
        }
    }
    
    func getAllTabs() -> BaseOperation<[DAppBrowserTab]> {
        let currentTabs = tabs
            .values
            .sorted { $0.lastModified < $1.lastModified }
        
        guard currentTabs.isEmpty else {
            return .createWithResult(currentTabs)
        }
        
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        
        let resultOperaton =  ClosureOperation { [weak self] in
            let tabs = try fetchOperation
                .extractNoCancellableResultData()
                .map { persistenceModel in
                    DAppBrowserTab(
                        uuid: persistenceModel.uuid,
                        name: persistenceModel.name,
                        url: persistenceModel.url,
                        lastModified: persistenceModel.lastModified,
                        opaqueState: self?.dAppTransportStates[persistenceModel.uuid],
                        stateRender: nil,
                        icon: persistenceModel.icon
                    )
                }
            
            tabs.forEach { self?.tabs[$0.uuid] = $0 }
            
            return tabs
        }
        resultOperaton.addDependency(fetchOperation)
        
        return resultOperaton
    }
    
    func removeTab(with id: UUID) {
        guard  let model = tabs[id]?.persistenceModel else {
            return
        }
        
        tabs[id] = nil
        
        let deleteOperation = repository.saveOperation(
            { [] },
            { [model.identifier] }
        )
        
        execute(
            operation: deleteOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: { _ in }
        )
    }
    
    func updateTab(_ tab: DAppBrowserTab) -> BaseOperation<DAppBrowserTab> {
        let persistenceModel = tab.persistenceModel
        
        let updateOperation = repository.saveOperation(
            { [persistenceModel] },
            { [] }
        )
        
        let resultOperation =  ClosureOperation { [weak self] in
            let _ = try updateOperation.extractNoCancellableResultData()
            
            self?.tabs[tab.uuid] = tab
            self?.dAppTransportStates[tab.uuid] = tab.opaqueState
            
            return tab
        }
        resultOperation.addDependency(updateOperation)
        
        return resultOperation
    }
    
    func createTab(for dApp: DApp) -> BaseOperation<DAppBrowserTab> {
        let tab = DAppBrowserTab(
            uuid: UUID(),
            name: dApp.name,
            url: dApp.url,
            lastModified: Date().timeIntervalSince1970,
            opaqueState: nil,
            stateRender: nil,
            icon: dApp.icon
        )
        
        let saveOperation = repository.saveOperation(
            { [tab.persistenceModel] },
            { [] }
        )
        
        let resultOperation =  ClosureOperation { [weak self] in
            let _ = try saveOperation.extractNoCancellableResultData()
            
            self?.tabs[tab.uuid] = tab
            
            return tab
        }
        resultOperation.addDependency(saveOperation)
        
        return resultOperation
    }
}
