import XCTest
@testable import novawallet
import SoraKeystore
import Cuckoo
import BigInt

final class SwapsValidationTests: XCTestCase {
    private func amountInPlank(_ amount: Decimal, _ chainAsset: ChainAsset) -> BigUInt {
        amount.toSubstrateAmount(precision: chainAsset.assetDisplayInfo.assetPrecision) ?? 0
    }
    
    func testCalculatedFeeWithoutED() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 3, addressPrefix: 42)
        let utilityChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 0 })!)
        let payChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 2 })!)
        let feeChainAsset = payChainAsset
        let accountId = try WestendStub.address.toAccountId()
        
        let freeBalance = amountInPlank(50, payChainAsset)
        let payAssetBalance = AssetBalance(chainAssetId: payChainAsset.chainAssetId,
                                           accountId: accountId,
                                           freeInPlank: freeBalance,
                                           reservedInPlank: 0,
                                           frozenInPlank: 0,
                                           blocked: false)
        let utilityAssetBalance = AssetBalance(chainAssetId: utilityChainAsset.chainAssetId,
                                               accountId: accountId,
                                               freeInPlank: 0,
                                               reservedInPlank: 0,
                                               frozenInPlank: 0,
                                               blocked: false)
        let existentialDeposit = amountInPlank(1, utilityChainAsset)
        let fee = amountInPlank(0.1, payChainAsset)
        let existentialDepositInFeeToken = amountInPlank(0.01, payChainAsset)
        
        let params = SwapFeeParams(
            fee: fee,
            feeChainAsset: payChainAsset,
            feeAssetBalance: payAssetBalance,
            edAmount: existentialDeposit,
            edAmountInFeeToken: existentialDepositInFeeToken,
            edChainAsset: utilityChainAsset,
            edChainAssetBalance: utilityAssetBalance,
            payChainAsset: payChainAsset,
            amountUpdateClosure: { _ in })
        
        let result = params.prepare(swapAmount: 50)
        
        XCTAssertEqual(result.availableToPay, 49.89)
       
    }
    
    func testCalculatedFeeWithED() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 3, addressPrefix: 42)
        let utilityChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 0 })!)
        let ksmChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 1 })!)
        let payChainAsset = ChainAsset(chain: chain, asset: chain.assets.first(where: { $0.assetId == 2 })!)
        let feeChainAsset = utilityChainAsset
        let accountId = try WestendStub.address.toAccountId()
        
        let freeBalance = amountInPlank(50, payChainAsset)
        let payAssetBalance = AssetBalance(chainAssetId: payChainAsset.chainAssetId,
                                           accountId: accountId,
                                           freeInPlank: freeBalance,
                                           reservedInPlank: 0,
                                           frozenInPlank: 0,
                                           blocked: false)
        let utilityAssetBalance = AssetBalance(chainAssetId: utilityChainAsset.chainAssetId,
                                               accountId: accountId,
                                               freeInPlank: 10,
                                               reservedInPlank: 0,
                                               frozenInPlank: 0,
                                               blocked: false)
        let existentialDeposit = amountInPlank(1, utilityChainAsset)
        let fee = amountInPlank(0.1, payChainAsset)
        let existentialDepositInFeeToken = amountInPlank(0.01, payChainAsset)
        
        let params = SwapFeeParams(
            fee: fee,
            feeChainAsset: payChainAsset,
            feeAssetBalance: payAssetBalance,
            edAmount: existentialDeposit,
            edAmountInFeeToken: existentialDepositInFeeToken,
            edChainAsset: utilityChainAsset,
            edChainAssetBalance: utilityAssetBalance,
            payChainAsset: payChainAsset,
            amountUpdateClosure: { _ in })
        
        let result = params.prepare(swapAmount: 50)
        
        XCTAssertEqual(result.availableToPay, 49.9)
       
    }
}
