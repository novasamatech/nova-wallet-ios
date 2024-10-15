import XCTest
@testable import novawallet
import IrohaCrypto

final class MnemonicTests: XCTestCase {
    func testFuzzyMnemonicGenerationRestore() throws {
        let attempts = 10000
        var allMnemonics = Set<String>()
        
        try (0..<attempts).forEach { _ in
            let mnemonicCreator = IRMnemonicCreator(language: .english)
            let originalMnemonic = try mnemonicCreator.randomMnemonic(.entropy128).toString()
            
            let restoredMnemonic = try mnemonicCreator.mnemonic(fromList: originalMnemonic).toString()
            
            XCTAssertEqual(originalMnemonic, restoredMnemonic)
            XCTAssertTrue(!allMnemonics.contains(originalMnemonic))
            
            allMnemonics.insert(originalMnemonic)
        }
        
        XCTAssertEqual(allMnemonics.count, attempts)
    }
}
