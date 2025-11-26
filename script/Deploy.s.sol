// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/TinfoilToken.sol";
import "../src/ConspiraPuppets.sol";
import "../src/LPManager.sol";

/**
 * SIMPLIFIED DEPLOYMENT SCRIPT - NOW WITH UNISWAP V3
 * 
 * No separate "owner tokens" - just mint yourself some NFTs!
 * Two-way split: NFT Holders + LP
 * 
 * UNISWAP V3 BENEFITS:
 * ✅ No governance approval needed for fee collection
 * ✅ 1% fee tier for optimal trading
 * ✅ Position permanently locked (can't be rugged)
 * ✅ Fees collectible immediately after LP creation
 */
contract DeployScript is Script {
    // =========================================================================
    // BASE MAINNET ADDRESSES
    // =========================================================================
    
    address constant SEADROP_ADDRESS = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;
    
    // Uniswap V3 (Base Mainnet)
    address constant UNISWAP_POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant UNISWAP_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address constant UNISWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    // =========================================================================
    // CONFIGURATION PRESETS
    // =========================================================================
    
    struct Config {
        string name;
        string symbol;
        string tokenName;
        string tokenSymbol;
        uint256 maxSupply;
        uint256 totalTokenSupply;
        uint256 nftHolderBps;  // LP gets the remainder (10000 - nftHolderBps)
    }

    // CUSTOM: ConspiraPuppets Configuration
    function getConspiraPuppetsConfig() internal pure returns (Config memory) {
        return Config({
            name: "FFFFF",
            symbol: "FFF",
            tokenName: "RRRRR",
            tokenSymbol: "RRR",
            maxSupply: 3333,
            totalTokenSupply: 3_333_333_333 * 10**18,
            nftHolderBps: 5000  // 50% to NFT holders, 50% to LP
        });
    }
    
    // PRESET 1: Original ConspiraPuppets (3,333 NFTs, 3.33B tokens)
    function getOriginalConfig() internal pure returns (Config memory) {
        return Config({
            name: "ConspiraPuppets",
            symbol: "CONSPIRA",
            tokenName: "Tinfoil",
            tokenSymbol: "TINFOIL",
            maxSupply: 3333,
            totalTokenSupply: 3_330_000_000 * 10**18,
            nftHolderBps: 5000  // 50% to NFT holders, 50% to LP
        });
    }
    
    // PRESET 2: 1 Billion Token Supply (10,000 NFTs, 1B tokens)
    function get1BillionConfig() internal pure returns (Config memory) {
        return Config({
            name: "MyNFTProject",
            symbol: "MNFT",
            tokenName: "MyToken",
            tokenSymbol: "MTK",
            maxSupply: 10000,
            totalTokenSupply: 1_000_000_000 * 10**18,
            nftHolderBps: 5000  // 50% to NFT holders, 50% to LP
        });
    }
    
    // PRESET 3: Higher LP (Better liquidity, deeper market)
    function getHighLiquidityConfig() internal pure returns (Config memory) {
        return Config({
            name: "LiquidProject",
            symbol: "LIQD",
            tokenName: "LiquidToken",
            tokenSymbol: "LIQD",
            maxSupply: 5000,
            totalTokenSupply: 500_000_000 * 10**18,
            nftHolderBps: 4000  // 40% to NFT holders, 60% to LP
        });
    }
    
    // PRESET 4: Higher to Holders (Better for collectors)
    function getCollectorFocusedConfig() internal pure returns (Config memory) {
        return Config({
            name: "CollectorProject",
            symbol: "COLL",
            tokenName: "CollectorToken",
            tokenSymbol: "COLL",
            maxSupply: 10000,
            totalTokenSupply: 1_000_000_000 * 10**18,
            nftHolderBps: 6000  // 60% to NFT holders, 40% to LP
        });
    }
    
    // =========================================================================
    // DEPLOYMENT FUNCTION
    // =========================================================================
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // =====================================================================
        // SELECT YOUR CONFIGURATION HERE
        // =====================================================================
        Config memory config = getConspiraPuppetsConfig();  // 👈 CHANGE THIS
        
        console.log("=================================================================");
        console.log("DEPLOYING NFT-TO-TOKEN SYSTEM WITH UNISWAP V3");
        console.log("=================================================================");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        console.log("");
        console.log("CONFIGURATION:");
        console.log("  NFT Name:", config.name);
        console.log("  NFT Symbol:", config.symbol);
        console.log("  Max NFT Supply:", config.maxSupply);
        console.log("  Token Name:", config.tokenName);
        console.log("  Token Symbol:", config.tokenSymbol);
        console.log("  Total Token Supply:", config.totalTokenSupply / 1e18);
        console.log("");
        
        uint256 lpBps = 10000 - config.nftHolderBps;
        console.log("DISTRIBUTION:");
        console.log("  NFT Holders:", config.nftHolderBps / 100, "%");
        console.log("  LP (Uniswap V3):", lpBps / 100, "%");
        console.log("");
        console.log("  [NOTE] Want tokens? Just mint NFTs for yourself!");
        console.log("");
        console.log("UNISWAP V3 BENEFITS:");
        console.log("  - No governance approval needed for fee collection");
        console.log("  - 1% fee tier for optimal trading");
        console.log("  - Position permanently locked");
        console.log("  - Owner can collect fees anytime with collectFees()");
        
        // Calculate amounts
        uint256 tokensPerNFT = (config.totalTokenSupply * config.nftHolderBps / 10000) / config.maxSupply;
        uint256 lpTokens = config.totalTokenSupply * lpBps / 10000;
        
        console.log("");
        console.log("CALCULATED AMOUNTS:");
        console.log("  Tokens per NFT:", tokensPerNFT / 1e18);
        console.log("  Total to NFT Holders:", (tokensPerNFT * config.maxSupply) / 1e18);
        console.log("  LP Tokens:", lpTokens / 1e18);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // =========================================================================
        // STEP 1: Deploy Token
        // =========================================================================
        console.log("\n[STEP 1] Deploying Token");
        TinfoilToken token = new TinfoilToken(
            config.tokenName,
            config.tokenSymbol,
            config.totalTokenSupply
        );
        console.log("  Token deployed at:", address(token));
        
        // =========================================================================
        // STEP 2: Deploy NFT Contract
        // =========================================================================
        console.log("\n[STEP 2] Deploying NFT Contract");
        
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = SEADROP_ADDRESS;
        
        ConspiraPuppets nft = new ConspiraPuppets(
            config.name,
            config.symbol,
            address(token),
            allowedSeaDrop,
            tokensPerNFT,
            lpTokens,
            config.totalTokenSupply
        );
        console.log("  NFT deployed at:", address(nft));
        
        // =========================================================================
        // STEP 3: Set Max Supply
        // =========================================================================
        console.log("\n[STEP 3] Setting max supply");
        nft.setMaxSupply(config.maxSupply);
        console.log("  [GOOD] Max supply set to", config.maxSupply);
        
        // =========================================================================
        // STEP 4: Deploy LP Manager (Uniswap V3)
        // =========================================================================
        console.log("\n[STEP 4] Deploying LP Manager (Uniswap V3)");
        LPManager lpManager = new LPManager(
            address(nft),
            address(token),
            UNISWAP_POSITION_MANAGER,
            UNISWAP_FACTORY
        );
        console.log("  LP Manager deployed at:", address(lpManager));
        
        // =========================================================================
        // STEP 5: Link LP Manager to NFT
        // =========================================================================
        console.log("\n[STEP 5] Linking LP Manager to NFT");
        nft.setLPManager(address(lpManager));
        console.log("  [GOOD] LP Manager set");
        
        // =========================================================================
        // STEP 6: Transfer LP Manager ownership to NFT
        // =========================================================================
        console.log("\n[STEP 6] Transferring LP Manager ownership");
        lpManager.transferOwnership(address(nft));
        console.log("  [GOOD] Ownership transferred");
        
        // =========================================================================
        // STEP 7: Link NFT to Token
        // =========================================================================
        console.log("\n[STEP 7] Linking NFT to Token");
        token.setNFTContract(address(nft));
        console.log("  [GOOD] NFT linked to Token");
        
        // =========================================================================
        // STEP 8: Configure whitelists (UNISWAP V3 ADDRESSES)
        // =========================================================================
        console.log("\n[STEP 8] Configuring transfer whitelist (Uniswap V3)");
        token.setTransferWhitelist(address(nft), true);
        token.setTransferWhitelist(UNISWAP_POSITION_MANAGER, true);
        token.setTransferWhitelist(UNISWAP_ROUTER, true);
        token.setTransferWhitelist(address(lpManager), true);
        token.setTransferWhitelist(WETH, true);
        console.log("  [GOOD] Whitelist configured with Uniswap V3 contracts");
        
        // =========================================================================
        // STEP 9: Configure fee recipient
        // =========================================================================
        console.log("\n[STEP 9] Configuring fee recipient");
        nft.updateAllowedFeeRecipient(SEADROP_ADDRESS, deployer, true);
        console.log("  [GOOD] Fee recipient set");
        
        // =========================================================================
        // STEP 10: Verification
        // =========================================================================
        console.log("\n[STEP 10] Running verification checks");
        require(token.nftContract() == address(nft), "NFT not linked");
        require(token.MAX_SUPPLY() == config.totalTokenSupply, "Token supply mismatch");
        require(nft.maxSupply() == config.maxSupply, "NFT supply mismatch");
        require(nft.TOKENS_PER_NFT() == tokensPerNFT, "Tokens per NFT mismatch");
        require(nft.LP_TOKEN_AMOUNT() == lpTokens, "LP tokens mismatch");
        require(nft.TOTAL_TOKEN_SUPPLY() == config.totalTokenSupply, "Total supply mismatch");
        require(!token.tradingEnabled(), "Trading already enabled");
        require(nft.lpManager() == address(lpManager), "LP Manager not set");
        console.log("  [GOOD] All verification checks passed");
        
        vm.stopBroadcast();
        
        // =========================================================================
        // DEPLOYMENT SUMMARY
        // =========================================================================
        console.log("\n=================================================================");
        console.log("DEPLOYMENT COMPLETE - UNISWAP V3");
        console.log("=================================================================");
        console.log("Token:", address(token));
        console.log("NFT:", address(nft));
        console.log("LP Manager:", address(lpManager));
        console.log("");
        console.log("Save to .env:");
        console.log("TOKEN_ADDRESS=%s", address(token));
        console.log("NFT_ADDRESS=%s", address(nft));
        console.log("LP_MANAGER_ADDRESS=%s", address(lpManager));
        console.log("");
        console.log("=================================================================");
        console.log("TOKENOMICS SUMMARY");
        console.log("=================================================================");
        console.log("Each NFT minted distributes:", tokensPerNFT / 1e18, "tokens");
        console.log("Total to NFT holders (", config.maxSupply, "NFTs):", (tokensPerNFT * config.maxSupply) / 1e18);
        console.log("LP receives:", lpTokens / 1e18, "tokens");
        console.log("Total supply:", config.totalTokenSupply / 1e18, "tokens");
        console.log("");
        console.log("=================================================================");
        console.log("UNISWAP V3 INFO");
        console.log("=================================================================");
        console.log("Position Manager:", UNISWAP_POSITION_MANAGER);
        console.log("Factory:", UNISWAP_FACTORY);
        console.log("Router:", UNISWAP_ROUTER);
        console.log("WETH:", WETH);
        console.log("Fee Tier: 1%");
        console.log("Position Range: Full (ticks -887220 to 887220)");
        console.log("");
        console.log("=================================================================");
        console.log("NEXT STEPS");
        console.log("=================================================================");
        console.log("1. Configure drop in OpenSea Studio:");
        console.log("   https://opensea.io/studio");
        console.log("   Import contract:", address(nft));
        console.log("");
        console.log("2. Set payout address:");
        console.log("   cast send %s \\", address(nft));
        console.log("     'updateCreatorPayoutAddress(address,address)' \\");
        console.log("     %s %s \\", SEADROP_ADDRESS, address(nft));
        console.log("     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL");
        console.log("");
        console.log("3. After mint complete, mark it:");
        console.log("   cast send %s 'setMintCompleted()' \\", address(nft));
        console.log("     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL");
        console.log("");
        console.log("4. Create LP (after 5 min delay or use createLPImmediate):");
        console.log("   cast send %s 'createLP()' \\", address(nft));
        console.log("     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL");
        console.log("");
        console.log("5. Withdraw operational funds:");
        console.log("   cast send %s 'withdrawOperationalFunds()' \\", address(nft));
        console.log("     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL");
        console.log("");
        console.log("6. COLLECT FEES (Owner only - no governance needed!):");
        console.log("   cast send %s 'collectFees()' \\", address(lpManager));
        console.log("     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL");
        console.log("");
        console.log("7. Withdraw collected fees:");
        console.log("   cast send %s 'withdrawAllTokens(address)' \\", address(lpManager));
        console.log("     %s \\", WETH);
        console.log("     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL");
        console.log("");
        console.log("   cast send %s 'withdrawAllTokens(address)' \\", address(lpManager));
        console.log("     %s \\", address(token));
        console.log("     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL");
        console.log("=================================================================");
        console.log("");
        console.log("UNISWAP V3 ADVANTAGES:");
        console.log("  - NO governance approval needed for fee collection");
        console.log("  - Owner can call collectFees() immediately");
        console.log("  - Fees available IMMEDIATELY after LP creation");
        console.log("  - Position locked forever (can't be rugged)");
        console.log("  - 1% fee tier = optimal for most tokens");
        console.log("=================================================================");
    }
}
