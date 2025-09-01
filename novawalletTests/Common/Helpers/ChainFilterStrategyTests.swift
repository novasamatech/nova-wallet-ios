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
        
        let currentChains = [
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
    
    // MARK: hasMultisig

    func testHasMultisigFilterDelete() {
        hasMultisigFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        hasMultisigFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }

    func hasMultisigFilterDeletes(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.hasMultisig
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasMultisig: true),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasMultisig: true)
        ].reduceToDict()
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                hasMultisig: !$0.hasMultisig
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        currentChains = resultChanges.mergeToDict(currentChains)
        
        // then
        XCTAssert(currentChains.isEmpty)
    }

    func testHasMultisigFilterInsert() {
        hasMultisigFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        hasMultisigFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }

    func hasMultisigFilterInserts(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.hasMultisig
        
        let currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasMultisig: false),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasMultisig: false)
        ].reduceToDict()
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                hasMultisig: !$0.hasMultisig
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        resultChains = resultChanges.mergeToDict(resultChains)
        
        // then
        XCTAssert(updatedChains.allSatisfy { resultChains[$0.chainId] != nil })
    }

    // MARK: hasDelegatedAccounts

    func testHasDelegatedAccountsFilterDelete() {
        hasDelegatedAccountsFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        hasDelegatedAccountsFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }

    func hasDelegatedAccountsFilterDeletes(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.hasDelegatedAccounts
        
        var currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: true, hasMultisig: false),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: false, hasMultisig: true),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: true, hasMultisig: true)
        ].reduceToDict()
        
        let updatedChains = currentChains.values.map {
            ChainModelGenerator.generateChain(
                defaultChainId: $0.chainId,
                generatingAssets: 0,
                addressPrefix: 0,
                hasProxy: false,
                hasMultisig: false
            )
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        currentChains = resultChanges.mergeToDict(currentChains)
        
        // then
        XCTAssert(currentChains.isEmpty)
    }

    func testHasDelegatedAccountsFilterInsert() {
        hasDelegatedAccountsFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        hasDelegatedAccountsFilterInserts { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        }
    }

    func hasDelegatedAccountsFilterInserts(changes: ([ChainModel]) -> [DataProviderChange<ChainModel>]) {
        // given
        let filterStrategy = ChainFilterStrategy.hasDelegatedAccounts
        
        let currentChains = [
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: false, hasMultisig: false),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: false, hasMultisig: false)
        ].reduceToDict()
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let updatedChains = currentChains.values.enumerated().map { index, chain in
            if index == 0 {
                // First chain gets proxy enabled
                return ChainModelGenerator.generateChain(
                    defaultChainId: chain.chainId,
                    generatingAssets: 0,
                    addressPrefix: 0,
                    hasProxy: true,
                    hasMultisig: false
                )
            } else {
                // Second chain gets multisig enabled
                return ChainModelGenerator.generateChain(
                    defaultChainId: chain.chainId,
                    generatingAssets: 0,
                    addressPrefix: 0,
                    hasProxy: false,
                    hasMultisig: true
                )
            }
        }
        
        let beforeFilterChanges = changes(updatedChains)
        
        // when
        let resultChanges = filterStrategy.filter(beforeFilterChanges, using: currentChains)
        resultChains = resultChanges.mergeToDict(resultChains)
        
        // then
        XCTAssert(updatedChains.allSatisfy { resultChains[$0.chainId] != nil })
    }

    // MARK: hasDelegatedAccounts - Additional edge case tests

    func testHasDelegatedAccountsFilterMixedConditions() {
        // Test that chains with either proxy OR multisig (or both) are included
        let filterStrategy = ChainFilterStrategy.hasDelegatedAccounts
        
        let testChains = [
            // Chain with only proxy - should be included
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0, hasProxy: true, hasMultisig: false),
            // Chain with only multisig - should be included
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 1, hasProxy: false, hasMultisig: true),
            // Chain with both - should be included
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 2, hasProxy: true, hasMultisig: true),
            // Chain with neither - should be excluded
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 3, hasProxy: false, hasMultisig: false)
        ]
        
        let changes = testChains.map { DataProviderChange<ChainModel>.insert(newItem: $0) }
        
        // when
        let resultChanges = filterStrategy.filter(changes, using: [:])
        
        // then
        XCTAssertEqual(resultChanges.count, 3) // Should exclude the chain with neither proxy nor multisig
        
        let resultChainIds = Set(resultChanges.compactMap { $0.item?.chainId })
        let expectedChainIds = Set(testChains.prefix(3).map { $0.chainId }) // First 3 chains
        
        XCTAssertEqual(resultChainIds, expectedChainIds)
    }
    
    // MARK: enabledChains
    
    func testEnabledChainsFilterDelete() {
        enabledChainsFilterDeletes { updatedChains in
            updatedChains.map { DataProviderChange<ChainModel>.update(newItem: $0) }
        }
        
        enabledChainsFilterDeletes { updatedChains in
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
        
        let currentChains = [
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
        
        let currentChains = [
            ChainModelGenerator.generateChain(assets: [], defaultChainId: chainId, addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0),
            ChainModelGenerator.generateChain(assets: [], addressPrefix: 0)
        ].reduceToDict()
        
        var resultChains: [ChainModel.Id: ChainModel] = [:]
        
        let updatedChains = currentChains.values.map { _ in
            ChainModelGenerator.generateChain(
                defaultChainId: Data.random(of: 32)!.toHex(),
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
                defaultChainId: Data.random(of: 32)!.toHex(),
                addressPrefix: 0
            ),
            ChainModelGenerator.generateChain(
                assets: [],
                defaultChainId: Data.random(of: 32)!.toHex(),
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
        
        let currentChains = [
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
