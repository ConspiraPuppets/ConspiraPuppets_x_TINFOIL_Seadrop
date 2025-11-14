// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);
}

interface IUniswapV3Pool {
    function initialize(uint160 sqrtPriceX96) external;
    
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

contract LPManager is Ownable, ReentrancyGuard {
    address public immutable nftContract;
    address public immutable token;
    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Factory public immutable factory;
    
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    uint24 public constant FEE_TIER = 10000; // 0.3%
    int24 public constant TICK_LOWER = -887220;
    int24 public constant TICK_UPPER = 887220;
    
    uint256 public positionTokenId;
    bool public lpCreated;
    
    event LPCreated(uint256 tokenId, uint128 liquidity, address pool);
    event PoolInitialized(address pool, uint160 sqrtPriceX96);
    event FeesCollected(uint256 amount0, uint256 amount1);
    event TokensWithdrawn(address token, uint256 amount);
    event ETHWithdrawn(uint256 amount);
    event EmergencyWithdrawal(uint256 amount);
    
    constructor(
        address _nftContract,
        address _token,
        address _positionManager,
        address _factory
    ) {
        require(_nftContract != address(0), "Invalid NFT contract");
        require(_token != address(0), "Invalid token");
        require(_positionManager != address(0), "Invalid position manager");
        require(_factory != address(0), "Invalid factory");
        
        nftContract = _nftContract;
        token = _token;
        positionManager = INonfungiblePositionManager(_positionManager);
        factory = IUniswapV3Factory(_factory);
    }
    
    function createAndLockLP(uint256 tokenAmount, uint256 slippageBps)
        external
        payable
        onlyOwner
        nonReentrant
        returns (bool)
    {
        require(!lpCreated, "LP already created");
        require(msg.value > 0, "No ETH provided");
        require(tokenAmount > 0, "No tokens provided");
        require(slippageBps <= 10000, "Invalid slippage");
        
        // Wrap ETH to WETH
        IWETH(WETH).deposit{value: msg.value}();
        
        // Approve tokens
        IERC20(token).approve(address(positionManager), tokenAmount);
        IWETH(WETH).approve(address(positionManager), msg.value);
        
        // Determine token order
        (address token0, address token1) = token < WETH 
            ? (token, WETH) 
            : (WETH, token);
        
        (uint256 amount0Desired, uint256 amount1Desired) = token < WETH
            ? (tokenAmount, msg.value)
            : (msg.value, tokenAmount);
        
        // Calculate minimum amounts with slippage
        uint256 amount0Min = (amount0Desired * (10000 - slippageBps)) / 10000;
        uint256 amount1Min = (amount1Desired * (10000 - slippageBps)) / 10000;
        
        // Create or get pool
        address pool = factory.getPool(token0, token1, FEE_TIER);
        bool needsInitialization = false;
        
        if (pool == address(0)) {
            // Pool doesn't exist, create it
            pool = factory.createPool(token0, token1, FEE_TIER);
            needsInitialization = true;
        } else {
            // Pool exists, check if it's initialized
            IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
            (uint160 sqrtPriceX96,,,,,,) = poolContract.slot0();
            if (sqrtPriceX96 == 0) {
                needsInitialization = true;
            }
        }
        
        // Initialize pool if needed with correct price
        if (needsInitialization) {
            // Calculate sqrtPriceX96 based on the ratio of amounts
            // sqrtPriceX96 = sqrt(amount1/amount0) * 2^96
            // To avoid overflow, we calculate: sqrt((amount1 * 2^96) / amount0) * 2^48
            
            uint256 ratioX192 = (amount1Desired << 192) / amount0Desired;
            uint160 sqrtPriceX96 = uint160(sqrt(ratioX192));
            
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
            emit PoolInitialized(pool, sqrtPriceX96);
        }
        
        // Mint position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: token0,
                token1: token1,
                fee: FEE_TIER,
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                recipient: address(this),
                deadline: block.timestamp + 300
            });
        
        (uint256 tokenId, uint128 liquidity, , ) = positionManager.mint(params);
        
        positionTokenId = tokenId;
        lpCreated = true;
        
        emit LPCreated(tokenId, liquidity, pool);
        
        return true;
    }
    
    /**
     * @notice Calculate square root using Babylonian method
     * @dev Used for calculating sqrtPriceX96
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    function collectFees() external onlyOwner nonReentrant {
        require(lpCreated, "LP not created");
        require(positionTokenId > 0, "No position");
        
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager
            .CollectParams({
                tokenId: positionTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        
        (uint256 amount0, uint256 amount1) = positionManager.collect(params);
        
        emit FeesCollected(amount0, amount1);
    }
    
    function withdrawAllTokens(address _token) external onlyOwner nonReentrant {
        require(_token != address(0), "Invalid token");
        
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        
        IERC20(_token).transfer(owner(), balance);
        
        emit TokensWithdrawn(_token, balance);
    }
    
    function withdrawAllETH() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "ETH transfer failed");
        
        emit ETHWithdrawn(balance);
    }
    
    /**
     * @notice Emergency function to withdraw all ETH
     * @dev Only callable by owner (NFT contract)
     */
    function emergencyWithdrawETH() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "ETH transfer failed");
        
        emit EmergencyWithdrawal(balance);
    }
    
    /**
     * @notice Emergency function to withdraw specific token
     * @param _token Token address to withdraw
     */
    function emergencyWithdrawTokens(address _token) external onlyOwner nonReentrant {
        require(_token != address(0), "Invalid token");
        
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        
        IERC20(_token).transfer(owner(), balance);
        
        emit TokensWithdrawn(_token, balance);
    }
    
    function getExpectedLPPair() public view returns (address) {
        (address token0, address token1) = token < WETH 
            ? (token, WETH) 
            : (WETH, token);
        return factory.getPool(token0, token1, FEE_TIER);
    }
    
    function getTokenBalance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
    
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getLPStatus() external view returns (
        bool created,
        uint256 tokenId,
        address pool
    ) {
        return (lpCreated, positionTokenId, getExpectedLPPair());
    }
    
    receive() external payable {}
}
