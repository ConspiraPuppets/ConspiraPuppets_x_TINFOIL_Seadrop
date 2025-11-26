// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISeaDrop} from "seadrop/src/interfaces/ISeaDrop.sol";
import {ERC721SeaDrop} from "seadrop/src/ERC721SeaDrop.sol";

interface ITinfoilToken {
    function mint(address to, uint256 amount) external;
    function setTransferWhitelist(address account, bool allowed) external;
    function enableTrading() external;
}

interface ILPManager {
    function createAndLockLP(uint256 tokenAmount, uint256 slippageBps) external payable returns (bool);
    function lpCreated() external view returns (bool);
    function positionTokenId() external view returns (uint256);
    function getExpectedLPPair() external view returns (address);
    function collectFees() external;
    function withdrawAllTokens(address token) external;
    function withdrawAllETH() external;
    function emergencyWithdrawETH() external;
    function emergencyWithdrawTokens(address token) external;
}

contract ConspiraPuppets is ERC721SeaDrop {
    address public immutable tinfoilToken;
    address public lpManager;
    
    uint256 public immutable TOKENS_PER_NFT;
    uint256 public immutable LP_TOKEN_AMOUNT;
    uint256 public immutable TOTAL_TOKEN_SUPPLY;
    uint256 public constant DEFAULT_SLIPPAGE_BPS = 5000; // 50%
    uint256 public constant LP_CREATION_DELAY = 5 minutes;
    
    bool public mintCompleted;
    bool public lpCreationScheduled;
    uint256 public lpCreationTimestamp;
    uint256 public operationalFunds;
    
    event MintCompleted(uint256 timestamp);
    event LPCreationScheduled(uint256 scheduledTime);
    event LPCreationAttempted(bool success, address caller);
    event FundsAllocated(uint256 lpAmount, uint256 operationalAmount);
    event OperationalFundsWithdrawn(address to, uint256 amount);
    event TradingEnabled();
    event LPManagerSet(address lpManager);
    event EmergencyWithdrawal(address to, uint256 amount);
    event TokensRecovered(address token, uint256 amount);
    event LPFeesCollected();
    event LPFeesWithdrawn(address token, uint256 amount);
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _tinfoilToken,
        address[] memory _allowedSeaDrop,
        uint256 _tokensPerNFT,
        uint256 _lpTokenAmount,
        uint256 _totalTokenSupply
    ) ERC721SeaDrop(_name, _symbol, _allowedSeaDrop) {
        require(_tinfoilToken != address(0), "Invalid token address");
        require(_tokensPerNFT > 0, "Invalid tokens per NFT");
        require(_lpTokenAmount > 0, "Invalid LP token amount");
        require(_totalTokenSupply > 0, "Invalid total supply");
        
        tinfoilToken = _tinfoilToken;
        TOKENS_PER_NFT = _tokensPerNFT;
        LP_TOKEN_AMOUNT = _lpTokenAmount;
        TOTAL_TOKEN_SUPPLY = _totalTokenSupply;
    }
    
    /**
     * @notice Override _mint to automatically distribute tokens on EVERY mint
     * @dev This ensures tokens are distributed whether minting through SeaDrop, airdrops, or any method
     * Also auto-completes mint when max supply is reached
     */
    function _mint(address to, uint256 quantity) internal virtual override {
        super._mint(to, quantity);
        
        // Distribute tokens to minter automatically
        ITinfoilToken(tinfoilToken).mint(to, TOKENS_PER_NFT * quantity);
        
        // Auto-complete when max supply reached
        if (totalSupply() >= maxSupply() && !mintCompleted) {
            mintCompleted = true;
            lpCreationScheduled = true;
            lpCreationTimestamp = block.timestamp + LP_CREATION_DELAY;
            emit MintCompleted(block.timestamp);
            emit LPCreationScheduled(lpCreationTimestamp);
        }
    }
    
    function setLPManager(address _lpManager) external onlyOwner {
        require(_lpManager != address(0), "Invalid LP Manager");
        require(lpManager == address(0), "LP Manager already set");
        lpManager = _lpManager;
        emit LPManagerSet(_lpManager);
    }
    
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
    
    function setMintCompleted() external onlyOwner {
        require(!mintCompleted, "Already completed");
        mintCompleted = true;
        lpCreationScheduled = true;
        lpCreationTimestamp = block.timestamp + LP_CREATION_DELAY;
        
        emit MintCompleted(block.timestamp);
        emit LPCreationScheduled(lpCreationTimestamp);
    }
    
    function createLP() external nonReentrant {
        require(mintCompleted, "Mint not completed yet");
        require(lpCreationScheduled, "LP creation not scheduled");
        require(block.timestamp >= lpCreationTimestamp, "LP creation delay not passed");
        require(lpManager != address(0), "LP Manager not set");
        require(!ILPManager(lpManager).lpCreated(), "LP already created");
        
        uint256 totalEth = address(this).balance;
        require(totalEth > 0, "No ETH in contract");
        
        uint256 lpEthAmount = totalEth;  // 100% to LP
        operationalFunds = 0;            // No operational funds
        
        emit FundsAllocated(lpEthAmount, operationalFunds);
        
        require(lpEthAmount > 0, "No ETH for LP");
        
        ITinfoilToken(tinfoilToken).mint(lpManager, LP_TOKEN_AMOUNT);
        
        bool success = ILPManager(lpManager).createAndLockLP{value: lpEthAmount}(
            LP_TOKEN_AMOUNT,
            DEFAULT_SLIPPAGE_BPS
        );
        
        emit LPCreationAttempted(success, msg.sender);
        
        if (success) {
            address lpPair = ILPManager(lpManager).getExpectedLPPair();
            if (lpPair != address(0)) {
                ITinfoilToken(tinfoilToken).setTransferWhitelist(lpPair, true);
            }
            
            ITinfoilToken(tinfoilToken).enableTrading();
            emit TradingEnabled();
        }
    }
    
    function createLPImmediate() external onlyOwner nonReentrant {
        require(mintCompleted, "Mint not completed yet");
        require(lpManager != address(0), "LP Manager not set");
        require(!ILPManager(lpManager).lpCreated(), "LP already created");
        
        uint256 totalEth = address(this).balance;
        require(totalEth > 0, "No ETH in contract");
        
        uint256 lpEthAmount = totalEth;  // 100% to LP
        operationalFunds = 0;            // No operational funds
        
        emit FundsAllocated(lpEthAmount, operationalFunds);
        
        ITinfoilToken(tinfoilToken).mint(lpManager, LP_TOKEN_AMOUNT);
        
        bool success = ILPManager(lpManager).createAndLockLP{value: lpEthAmount}(
            LP_TOKEN_AMOUNT,
            DEFAULT_SLIPPAGE_BPS
        );
        
        emit LPCreationAttempted(success, msg.sender);
        
        if (success) {
            address lpPair = ILPManager(lpManager).getExpectedLPPair();
            if (lpPair != address(0)) {
                ITinfoilToken(tinfoilToken).setTransferWhitelist(lpPair, true);
            }
            
            ITinfoilToken(tinfoilToken).enableTrading();
            emit TradingEnabled();
        }
    }
    
    function withdrawOperationalFunds() external onlyOwner nonReentrant {
        require(operationalFunds > 0, "No operational funds");
        
        uint256 amount = operationalFunds;
        operationalFunds = 0;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit OperationalFundsWithdrawn(msg.sender, amount);
    }
    
    /**
     * @notice Collect trading fees from the LP position
     * @dev Calls collectFees() on LP Manager, fees remain in LP Manager until withdrawn
     */
    function collectLPFees() external onlyOwner nonReentrant {
        require(lpManager != address(0), "LP Manager not set");
        require(ILPManager(lpManager).lpCreated(), "LP not created");
        
        ILPManager(lpManager).collectFees();
        
        emit LPFeesCollected();
    }
    
    /**
     * @notice Withdraw WETH fees from LP Manager to owner
     * @dev Must call collectLPFees() first to collect fees into LP Manager
     */
    function withdrawLPFeesWETH() external onlyOwner nonReentrant {
        require(lpManager != address(0), "LP Manager not set");
        
        address weth = 0x4200000000000000000000000000000000000006;
        ILPManager(lpManager).withdrawAllTokens(weth);
        
        // Fees are now in this contract, transfer to owner
        uint256 balance = IERC20(weth).balanceOf(address(this));
        if (balance > 0) {
            IERC20(weth).transfer(msg.sender, balance);
            emit LPFeesWithdrawn(weth, balance);
        }
    }
    
    /**
     * @notice Withdraw token fees from LP Manager to owner
     * @dev Must call collectLPFees() first to collect fees into LP Manager
     */
    function withdrawLPFeesTokens() external onlyOwner nonReentrant {
        require(lpManager != address(0), "LP Manager not set");
        
        ILPManager(lpManager).withdrawAllTokens(tinfoilToken);
        
        // Fees are now in this contract, transfer to owner
        uint256 balance = IERC20(tinfoilToken).balanceOf(address(this));
        if (balance > 0) {
            IERC20(tinfoilToken).transfer(msg.sender, balance);
            emit LPFeesWithdrawn(tinfoilToken, balance);
        }
    }
    
    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        operationalFunds = 0;
        
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit EmergencyWithdrawal(msg.sender, balance);
    }
    
    function recoverLPManagerETH() external onlyOwner nonReentrant {
        require(lpManager != address(0), "LP Manager not set");
        
        ILPManager(lpManager).emergencyWithdrawETH();
        
        uint256 recovered = address(this).balance;
        if (recovered > 0) {
            (bool success, ) = payable(msg.sender).call{value: recovered}("");
            require(success, "Transfer failed");
            emit EmergencyWithdrawal(msg.sender, recovered);
        }
    }
    
    function recoverLPManagerTokens(address token) external onlyOwner nonReentrant {
        require(lpManager != address(0), "LP Manager not set");
        require(token != address(0), "Invalid token");
        
        ILPManager(lpManager).emergencyWithdrawTokens(token);
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(msg.sender, balance);
            emit TokensRecovered(token, balance);
        }
    }
    
    function getLPCreationStatus() external view returns (
        bool _lpCreationScheduled,
        uint256 _lpCreationTimestamp,
        bool _canCreateLP,
        uint256 _timeRemaining
    ) {
        _lpCreationScheduled = lpCreationScheduled;
        _lpCreationTimestamp = lpCreationTimestamp;
        _canCreateLP = lpCreationScheduled && block.timestamp >= lpCreationTimestamp;
        _timeRemaining = lpCreationScheduled && block.timestamp < lpCreationTimestamp
            ? lpCreationTimestamp - block.timestamp
            : 0;
    }
    
    receive() external payable {}
}
