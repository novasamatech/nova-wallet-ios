import XCTest
import Operation_iOS
@testable import novawallet

class ChainFilterStrategyTests: XCTestCase {
    
    // MARK: hasProxy
    
    func testHasProxyFilterDelete() {
        hasProxyFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        hasProxyFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }
    
    func hasProxyFilterDeletes(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.hasProxy
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: true),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: true)
        ].reduceToDict()
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                hasProxy: !$0.hasProxy
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        currentChains = resultChanges.mergeToDict(currentChains)
        
        // then
        XCTAssert(currentChains.isEmpty)
    }
    
    func testHasProxyFilterInsert() {
        hasProxyFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        hasProxyFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }
    
    func hasProxyFilterInserts(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.hasProxy
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: false),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: false)
        ].reduceToDict()
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                hasProxy: !$0.hasProxy
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        resultChains = resultChanges.mergeToDict(resultChains)
        
        // then
        XCTAssert(updatedChains.allSatisfy { resultChains[$0.chainId] != nil })
    }
    
    // MARK: enabledChains
    
    func testEnabledChainsFilterDelete() {
        hasProxyFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        hasProxyFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }
    
    func enabledChainsFilterDeletes(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.enabledChains
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, enabled: true),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, enabled: true)
        ].reduceToDict()
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                enabled: !($0.syncMode == .full)
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        currentChains = resultChanges.mergeToDict(currentChains)
        
        // then
        XCTAssert(currentChains.isEmpty)
    }
    
    func testEnabledChainsFilterFilterInsert() {
        enabledChainsFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        enabledChainsFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }
    
    func enabledChainsFilterInserts(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.enabledChains
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, enabled: false),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, enabled: false)
        ].reduceToDict()
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                enabled: true
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        resultChains = resultChanges.mergeToDict(resultChains)
        
        // then
        XCTAssert(updatedChains.allSatisfy { resultChains[$0.chainId] != nil })
    }
    
    // MARK: chainId
    
    func testChainIdFilterDelete() {
        chainIdFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.delete(deletedIdentifier: $0.chainId) }
        }
    }
    
    func chainIdFilterDeletes(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let chainId = Data.random(of: 32)!.toHex()
        
        let filterStrategy = ChainFilterStrategy.chainId(chainId)
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], defaultChainId: chainId, addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0)
        ].reduceToDict()
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let updatedChains = currentChains.values.map { _ in
            ChainModelGenerator.generateChain(
                defaultChainId: generateChainId(notMatching: chainId),
                generatingAssets: 0,
                addressPrefix: 0
            )
        }
        
        let targetChainIdChains = [
            ChainModelGenerator.generateChain(
                defaultChainId: chainId,
                generatingAssets: 0,
                addressPrefix: 0
            )
        ]
        
        
        let beforeFilterChanges = changes(updatedChains + targetChainIdChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        resultChains = resultChanges.mergeToDict(currentChains)
        
        let successCondition = resultChains[chainId] == nil
            && resultChains.count == currentChains.count - targetChainIdChains.count
        
        // then
        XCTAssert(successCondition)
    }
    
    func testChainIdFilterInsert() {
        chainIdFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        chainIdFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }
    
    func chainIdFilterInserts(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let chainId = Data.random(of: 32)!.toHex()
        
        let filterStrategy = ChainFilterStrategy.chainId(chainId)
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let newChains = [
            ChainModelGenerator.generateChain(
                assets: [],
                defaultChainId: generateChainId(notMatching: chainId),
                addressPrefix: 0
            ),
            ChainModelGenerator.generateChain(
                assets: [],
                defaultChainId: generateChainId(notMatching: chainId),
                addressPrefix: 0
            )
        ]
        
        let targetChainIdChains = [ChainModelGenerator.generateChain(
            defaultChainId: chainId,
            generatingAssets: 0,
            addressPrefix: 0
        )]
        
        let beforeFilterChanges = changes(newChains + targetChainIdChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: [:])
        resultChains = resultChanges.mergeToDict(resultChains)
        
        // then
        XCTAssert(resultChains[chainId] != nil && resultChains.count == targetChainIdChains.count)
    }
    
    func generateChainId(notMatching chainId: String) -> String {
        let newChainId = Data.random(of: 32)!.toHex()
        
        guard newChainId != chainId else {
            return generateChainId(notMatching: chainId)
        }
        
        return newChainId
    }
    
    // MARK: allSatisfies
    
    func testAllSatisfiesFilterDelete() {
        allSatisfiesDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        allSatisfiesDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }
    
    func allSatisfiesDeletes(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        let chainId = Data.random(of: 32)!.toHex()
        
        // given
        let filterStrategy = ChainFilterStrategy.allSatisfies(
            [.hasProxy, .enabledChains]
        )
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: false, enabled: true),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: true, enabled: false)
        ].reduceToDict()
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                hasProxy: false,
                enabled: false
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        currentChains = resultChanges.mergeToDict(currentChains)
        
        // then
        XCTAssert(currentChains.isEmpty)
    }
    
    func testAllSatisfiesFilterInsert() {
        allSatisfiesFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        allSatisfiesFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }
    
    func allSatisfiesFilterInserts(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.allSatisfies(
            [.hasProxy, .enabledChains]
        )
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: true, enabled: false),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: false, enabled: true)
        ].reduceToDict()
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                hasProxy: true,
                enabled: true
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        resultChains = resultChanges.mergeToDict(resultChains)
        
        // then
        XCTAssert(updatedChains.allSatisfy { resultChains[$0.chainId] != nil })
    }
}
