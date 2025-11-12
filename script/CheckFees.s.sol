// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/interfaces/Interfaces.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract CheckFeesScript is Script {
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    
    function run() external view {
        // Get addresses from environment or use defaults
        address lpManagerAddress = vm.envOr("LP_MANAGER_ADDRESS", address(0));
        
        if (lpManagerAddress == address(0)) {
            console.log("LP_MANAGER_ADDRESS not set in .env");
            return;
        }
        
        console.log("=== LP Manager Fee Status ===");
        console.log("LP Manager:", lpManagerAddress);
        console.log("");
        
        // Check WETH balance
        uint256 wethBalance = IERC20(WETH).balanceOf(lpManagerAddress);
        console.log("WETH Balance:", wethBalance);
        
        // Check AERO balance
        uint256 aeroBalance = IERC20(AERO).balanceOf(lpManagerAddress);
        console.log("AERO Balance:", aeroBalance);
        
        // Check token balance (if set)
        address tokenAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        if (tokenAddress != address(0)) {
            uint256 tokenBalance = IERC20(tokenAddress).balanceOf(lpManagerAddress);
            console.log("Token Balance:", tokenBalance);
        }
        
        console.log("");
        console.log("To claim fees: cast send $LP_MANAGER_ADDRESS 'claimFees()' --private-key $PRIVATE_KEY --rpc-url base");
    }
}
