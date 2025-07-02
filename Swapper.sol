// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IVerifier
 * @dev Interface for external contract verification
 */
interface IVerifier {
    /**
     * @dev Verifies swap parameters on external contract
     * @param swapContract Address of the swap contract
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @param amountA Amount of token A
     * @param amountB Amount of token B
     * @param amountIn Input amount for swap
     * @param author Author identifier
     */
    function verify(
        address swapContract,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 amountIn,
        string calldata author
    ) external;
}

/**
 * @title Swapper
 * @dev Automated Market Maker (AMM) contract implementing Uniswap-like functionality
 * @dev Supports adding/removing liquidity, swapping tokens, and price calculations
 * @dev Uses constant product formula (x * y = k)
 */
contract Swapper {
    /// @notice The address of token A
    IERC20 public tokenA;
    /// @notice The address of token B
    IERC20 public tokenB;
    
    /// @notice Current reserve of token A in the pool
    uint256 public reserveA;
    /// @notice Current reserve of token B in the pool
    uint256 public reserveB;
    /// @notice Total liquidity tokens minted
    uint256 public totalLiquidity;

    /// @notice Emitted when liquidity is added to the pool
    event AddLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    /// @notice Emitted when liquidity is removed from the pool
    event RemoveLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    /// @notice Emitted when a swap is performed
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, address indexed to);

    /**
     * @dev Constructor initializes the Swapper contract with two token addresses
     * @param _tokenA Address of the first token (e.g., Ethereum)
     * @param _tokenB Address of the second token (e.g., Bitcoin)
     * @notice The order of tokens determines the swap direction and price calculations
     */
    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /**
     * @notice Adds liquidity to the pool and mints liquidity tokens
     * @dev First liquidity provider can add any amounts, subsequent providers must maintain ratio
     * @param _tokenA Address of token A (must match contract's tokenA)
     * @param _tokenB Address of token B (must match contract's tokenB)
     * @param amountADesired Desired amount of token A to add
     * @param amountBDesired Desired amount of token B to add
     * @param amountAMin Minimum acceptable amount of token A (slippage protection)
     * @param amountBMin Minimum acceptable amount of token B (slippage protection)
     * @param to Address that will receive the liquidity tokens
     * @param deadline Unix timestamp after which the transaction will revert
     * @return amountA Actual amount of token A added
     * @return amountB Actual amount of token B added
     * @return liquidity Amount of liquidity tokens minted
     */
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(deadline >= block.timestamp, "Expired");
        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "Invalid tokens");
        require(to != address(0), "Invalid recipient");

        // Calculate optimal amounts
        if (totalLiquidity == 0) {
            // First liquidity provider
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            // Calculate based on current ratio
            uint256 amountBOptimal = amountADesired * reserveB / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = amountBDesired * reserveA / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        require(amountA > 0 && amountB > 0, "Insufficient amounts");

        // Transfer tokens
        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        // Calculate liquidity
        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                amountA * totalLiquidity / reserveA,
                amountB * totalLiquidity / reserveB
            );
        }

        // Update reserves
        reserveA = reserveA + amountA;
        reserveB = reserveB + amountB;
        totalLiquidity = totalLiquidity + liquidity;

        emit AddLiquidity(to, amountA, amountB, liquidity);
    }

    /**
     * @notice Removes liquidity from the pool and returns underlying tokens
     * @dev Burns liquidity tokens and returns proportional amounts of underlying tokens
     * @param _tokenA Address of token A (must match contract's tokenA)
     * @param _tokenB Address of token B (must match contract's tokenB)
     * @param liquidity Amount of liquidity tokens to burn
     * @param amountAMin Minimum amount of token A to receive (slippage protection)
     * @param amountBMin Minimum amount of token B to receive (slippage protection)
     * @param to Address that will receive the underlying tokens
     * @param deadline Unix timestamp after which the transaction will revert
     * @return amountA Amount of token A received
     * @return amountB Amount of token B received
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(deadline >= block.timestamp, "Expired");
        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "Invalid tokens");
        require(to != address(0), "Invalid recipient");
        require(liquidity > 0, "Invalid liquidity");

        // Calculate amounts
        amountA = liquidity * reserveA / totalLiquidity;
        amountB = liquidity * reserveB / totalLiquidity;

        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient amounts");

        // Update reserves
        reserveA = reserveA - amountA;
        reserveB = reserveB - amountB;
        totalLiquidity = totalLiquidity - liquidity;

        // Transfer tokens
        require(tokenA.transfer(to, amountA), "Transfer A failed");
        require(tokenB.transfer(to, amountB), "Transfer B failed");

        emit RemoveLiquidity(to, amountA, amountB, liquidity);
    }

    /**
     * @notice Swaps exact input amount of tokens for output tokens
     * @dev Currently supports only direct swaps (A to B or B to A)
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMin Minimum amount of output tokens to receive (slippage protection)
     * @param path Array of token addresses [inputToken, outputToken]
     * @param to Address that will receive the output tokens
     * @param deadline Unix timestamp after which the transaction will revert
     * @return amounts Array containing [inputAmount, outputAmount]
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        require(path.length == 2, "Invalid path");
        require(path[0] == address(tokenA) && path[1] == address(tokenB), "Invalid tokens");
        require(to != address(0), "Invalid recipient");

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = getAmountOut(amountIn, reserveA, reserveB);

        require(amounts[1] >= amountOutMin, "Insufficient output");

        // Transfer tokens
        require(tokenA.transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
        require(tokenB.transfer(to, amounts[1]), "Transfer out failed");

        // Update reserves
        reserveA = reserveA + amountIn;
        reserveB = reserveB - amounts[1];

        emit Swap(msg.sender, amountIn, amounts[1], to);
    }

    /**
     * @notice Gets the current price of tokenA in terms of tokenB
     * @dev Price is calculated as reserveB / reserveA * 1e18
     * @param _tokenA Address of token A (must match contract's tokenA)
     * @param _tokenB Address of token B (must match contract's tokenB)
     * @return price Price of tokenA in terms of tokenB with 18 decimal precision
     */
    function getPrice(address _tokenA, address _tokenB) external view returns (uint256 price) {
        require(_tokenA == address(tokenA) && _tokenB == address(tokenB), "Invalid tokens");
        require(reserveB > 0, "Insufficient reserves");
        price = reserveB * 1e18 / reserveA;
    }

    /**
     * @notice Calculates the output amount for a given input using the AMM formula
     * @dev Uses constant product formula: (amountIn * reserveOut) / (reserveIn + amountIn)
     * @param amountIn Amount of input tokens
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Expected output amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        // No fee: amountOut = (amountIn * reserveOut) / (reserveIn + amountIn)
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }

    /**
     * @dev Calculates the integer square root using Newton's method
     * @param y Number to calculate square root of
     * @return z Integer square root of y
     * @notice Used for calculating initial liquidity tokens
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @dev Returns the smaller of two numbers
     * @param a First number
     * @param b Second number
     * @return The smaller of a and b
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Returns the current reserves of both tokens
     * @dev This is a view function that doesn't modify state
     * @return reserveA_ Current reserve of token A
     * @return reserveB_ Current reserve of token B
     */
    function getReserves() external view returns (uint256 reserveA_, uint256 reserveB_) {
        return (reserveA, reserveB);
    }

    /**
     * @notice Calls the verify function on an external contract
     * @dev The external contract must implement the IVerifier interface
     * @param verifierAddress Address of the external verifier contract
     * @param _tokenA Address of token A
     * @param _tokenB Address of token B
     * @param amountA_ Amount of token A for verification
     * @param amountB_ Amount of token B for verification
     * @param amountIn_ Input amount for verification
     * @param author_ Author identifier string
     */
    function callVerifyOnOtherContract(
        address verifierAddress,
        address _tokenA,
        address _tokenB,
        uint256 amountA_,
        uint256 amountB_,
        uint256 amountIn_,
        string calldata author_
    ) external {
        IVerifier(verifierAddress).verify(
            address(this),
            _tokenA,
            _tokenB,
            amountA_,
            amountB_,
            amountIn_,
            author_
        );
    }
}


    


