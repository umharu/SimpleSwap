// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title EthereumToken
 * @dev ERC20 token contract representing Ethereum on Ethereum blockchain
 * @dev Implements the standard ERC20 interface with additional utility functions
 * @dev Mints 100,000 ETH tokens to the contract creator upon deployment
 * @dev Uses OpenZeppelin's ERC20 implementation for security and standards compliance
 */
contract EthereumToken is ERC20 {

    /**
     * @dev Address of the contract owner/creator
     * @notice This address has special privileges and receives the initial token supply
     */
    address public owner;

    /**
     * @dev Address of this token contract
     * @notice Stored for easy access during contract development and integration
     * @notice Useful for external contracts that need to reference this token
     */
    address public addressToken;

    /**
     * @dev Constructor initializes the Ethereum token
     * @notice Sets token name to "Ethereum" and symbol to "ETH"
     * @notice Mints 100,000 ETH tokens to the contract creator
     * @notice Sets the owner to the contract creator
     * @notice Stores the contract address for easy reference
     * @notice Uses 18 decimals (standard for ERC20 tokens)
     */
    constructor() ERC20 ("Ethereum", "ETH") {
        // The contract creator receives an initial supply of 100,000 ETH
        _mint(msg.sender, 100000 * 10**decimals());
        owner = msg.sender;
        addressToken = address(this);
    }

}



