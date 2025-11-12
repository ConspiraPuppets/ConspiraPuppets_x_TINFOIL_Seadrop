#!/usr/bin/env python3
"""
Simplified Token Distribution Calculator
Two-way split: NFT Holders + LP

No separate "owner tokens" - just mint yourself some NFTs!
"""

def calculate_distribution(max_supply, total_tokens, nft_holder_pct):
    """
    Calculate token distribution amounts (simplified two-way split)
    
    Args:
        max_supply: Number of NFTs (e.g., 10000)
        total_tokens: Total token supply (e.g., 1000000000 for 1B)
        nft_holder_pct: Percentage to NFT holders (e.g., 50 for 50%)
                        LP automatically gets the remainder
    """
    
    # Validate percentage
    if nft_holder_pct <= 0 or nft_holder_pct >= 100:
        print(f"❌ Error: NFT holder percentage must be between 0 and 100 (got {nft_holder_pct}%)")
        return
    
    lp_pct = 100 - nft_holder_pct
    
    # Calculate amounts
    nft_holder_tokens = int(total_tokens * nft_holder_pct / 100)
    tokens_per_nft = nft_holder_tokens // max_supply
    lp_tokens = int(total_tokens * lp_pct / 100)
    
    # Calculate basis points (for Solidity)
    nft_holder_bps = int(nft_holder_pct * 100)
    
    # Display results
    print("=" * 70)
    print("TOKEN DISTRIBUTION CALCULATOR (SIMPLIFIED)")
    print("=" * 70)
    print(f"\n📊 INPUTS:")
    print(f"   Max NFT Supply: {max_supply:,}")
    print(f"   Total Token Supply: {total_tokens:,}")
    print(f"\n📈 DISTRIBUTION:")
    print(f"   NFT Holders: {nft_holder_pct}%")
    print(f"   Liquidity Pool: {lp_pct}% (automatic)")
    
    print(f"\n💰 AMOUNTS:")
    print(f"   Each NFT = {tokens_per_nft:,} tokens")
    print(f"   Total to NFT Holders = {nft_holder_tokens:,} tokens ({nft_holder_pct}%)")
    print(f"   LP Receives = {lp_tokens:,} tokens ({lp_pct}%)")
    
    print(f"\n⚙️  SOLIDITY PARAMETERS:")
    print(f"   maxSupply: {max_supply}")
    print(f"   totalTokenSupply: {total_tokens} * 10**18")
    print(f"   nftHolderBps: {nft_holder_bps}")
    
    print(f"\n📝 CONSTRUCTOR CALL:")
    print(f"   ConspiraPuppets(")
    print(f"       \"YourName\",")
    print(f"       \"SYMBOL\",")
    print(f"       allowedSeaDrop,")
    print(f"       tokenAddress,")
    print(f"       lpManagerAddress,")
    print(f"       {max_supply},                    // maxSupply")
    print(f"       {total_tokens} * 10**18,       // totalTokenSupply")
    print(f"       {nft_holder_bps}                     // nftHolderBps (LP gets remainder)")
    print(f"   )")
    
    print(f"\n🎨 GETTING YOUR TOKENS:")
    print(f"   Option 1: Airdrop yourself {10} NFTs = {tokens_per_nft * 10:,} tokens")
    print(f"   Option 2: Airdrop yourself {100} NFTs = {tokens_per_nft * 100:,} tokens")
    print(f"   Option 3: Just buy during public mint!")
    print(f"")
    print(f"   Command to airdrop:")
    print(f"   cast send $NFT_ADDRESS \\")
    print(f"     'airdrop(address[],uint256[])' \\")
    print(f"     '[YOUR_ADDRESS]' '[QUANTITY]' \\")
    print(f"     --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL")
    
    # Market cap estimates at different prices
    print(f"\n💵 MARKET CAP ESTIMATES:")
    print(f"   (Based on circulating supply to NFT holders + LP)")
    circulating = nft_holder_tokens + lp_tokens
    
    prices = [0.0001, 0.001, 0.01, 0.1, 1.0]
    for price in prices:
        mcap = circulating * price
        print(f"   At ${price:.4f}/token: ${mcap:,.0f}")
    
    # NFT pricing recommendations
    print(f"\n🎨 NFT PRICING RECOMMENDATIONS:")
    mint_revenues = [0.0001, 0.001, 0.01, 0.1]
    for eth_per_nft in mint_revenues:
        total_revenue = eth_per_nft * max_supply
        lp_eth = total_revenue * 0.5
        
        # Assuming 1 ETH = $3000 for example
        eth_price = 3000
        lp_value_usd = lp_eth * eth_price
        
        initial_price = lp_value_usd / lp_tokens if lp_tokens > 0 else 0
        
        print(f"\n   At {eth_per_nft} ETH per NFT:")
        print(f"      Total Revenue: {total_revenue:.2f} ETH (${total_revenue * eth_price:,.0f})")
        print(f"      LP Gets: {lp_eth:.2f} ETH + {lp_tokens:,} tokens")
        print(f"      Estimated Initial Token Price: ${initial_price:.6f}")
        print(f"      Initial Market Cap: ${initial_price * circulating:,.0f}")
    
    print("\n" + "=" * 70)


def preset_configs():
    """Show preset configurations"""
    print("\n🎯 PRESET CONFIGURATIONS\n")
    
    configs = [
        {
            "name": "50/50 Split (Balanced)",
            "max_supply": 10000,
            "total_tokens": 1_000_000_000,
            "nft_holder_pct": 50
        },
        {
            "name": "60/40 Split (Collector Focused)",
            "max_supply": 10000,
            "total_tokens": 1_000_000_000,
            "nft_holder_pct": 60
        },
        {
            "name": "40/60 Split (High Liquidity)",
            "max_supply": 5000,
            "total_tokens": 500_000_000,
            "nft_holder_pct": 40
        },
        {
            "name": "Original ConspiraPuppets",
            "max_supply": 3333,
            "total_tokens": 3_330_000_000,
            "nft_holder_pct": 50
        }
    ]
    
    for i, config in enumerate(configs, 1):
        lp_pct = 100 - config['nft_holder_pct']
        tokens_per_nft = int(config['total_tokens'] * config['nft_holder_pct'] / 100) // config['max_supply']
        
        print(f"\n{i}. {config['name']}")
        print(f"   Supply: {config['max_supply']:,} NFTs | {config['total_tokens']:,} tokens")
        print(f"   Distribution: {config['nft_holder_pct']}% NFTs | {lp_pct}% LP")
        print(f"   Each NFT: {tokens_per_nft:,} tokens")


if __name__ == "__main__":
    import sys
    
    print("\n" + "=" * 70)
    print("SIMPLIFIED NFT-TO-TOKEN CALCULATOR")
    print("Two-way split: NFT Holders + LP")
    print("=" * 70)
    
    if len(sys.argv) > 1 and sys.argv[1] == "presets":
        preset_configs()
        sys.exit(0)
    
    if len(sys.argv) == 4:
        # Command line usage
        max_supply = int(sys.argv[1])
        total_tokens = int(sys.argv[2])
        nft_holder_pct = float(sys.argv[3])
        
        calculate_distribution(max_supply, total_tokens, nft_holder_pct)
    else:
        # Interactive mode
        print("\nUsage: python3 calculator_simple.py <max_supply> <total_tokens> <nft_holder_%>")
        print("   Or: python3 calculator_simple.py presets")
        print("\nExample: python3 calculator_simple.py 10000 1000000000 50")
        print("         (10K NFTs, 1B tokens, 50% to holders, 50% to LP)\n")
        
        print("Running example calculation:\n")
        calculate_distribution(
            max_supply=10000,
            total_tokens=1_000_000_000,
            nft_holder_pct=50
        )
        
        print("\n\nTo see preset configurations, run: python3 calculator_simple.py presets")
