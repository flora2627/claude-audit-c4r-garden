// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./HTLC.sol";
import "./NativeHTLC.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title   UniqueDepositAddress
 * @notice  A proxy contract that allows users to have unique ERC20 deposit addresses for HTLC swaps
 *          Clone will not exist until the user deposits funds to the predetermined address.
 * @dev     This contract is cloned for each new deposit address and initialized with swap parameters
 */
contract UniqueDepositAddress is Initializable {
    using Clones for address;
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice  Initializes the proxy contract with HTLC swap parameters, and initiates
     *          the atomic swap. The happy flow of this contract ends when this gets called.
     */
    function initialize() public initializer {
        (
            address _addressHTLC,
            address refundAddress,
            address redeemer,
            uint256 timelock,
            bytes32 secretHash,
            uint256 amount,
            bytes memory destinationData
        ) = getArgs();
        HTLC(_addressHTLC).token().approve(_addressHTLC, amount);
        HTLC(_addressHTLC).initiateOnBehalf(refundAddress, redeemer, timelock, amount, secretHash, destinationData);
    }

    /**
     * @dev  Fetches the arguments passed during contract cloning.
     * @return  addressHTLC     The address of the HTLC contract.
     * @return  refundAddress   The refund/recovery address that will be able to refund the swap/recover accidental funds sent to the UDA.
     * @return  redeemer        The address that can redeem the swap with the secret.
     * @return  timelock        The number of blocks before the refund address can reclaim the funds.
     * @return  secretHash      The hash of the secret required for redemption.
     * @return  amount          The amount to swap.
     */
    function getArgs() internal view returns (address, address, address, uint256, bytes32, uint256, bytes memory) {
        bytes memory args = address(this).fetchCloneArgs();
        return abi.decode(args, (address, address, address, uint256, bytes32, uint256, bytes));
    }

    /**
     * @notice  Allows the owner to recover any tokens accidentally sent to this contract
     * @dev     Always sends the funds to the owner (refundAddress) of the contract
     *          NOTE: Publicly callable by anyone. This is intentional/safe because destination is hardcoded.
     * @param   _token  The ERC20 token to recover
     */
    function recover(address _token) public {
        (, address refundAddress,,,,,) = getArgs();
        IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
    }

    /**
     * @notice  Allows the owner to recover any eth accidentally sent to this contract
     * @dev     Always sends the funds to the owner (refundAddress) of the contract
     *          NOTE: Publicly callable by anyone. This is intentional/safe because destination is hardcoded.
     */
    function recover() public {
        (, address _refundAddress,,,,,) = getArgs();
        payable(_refundAddress).transfer(address(this).balance);
    }
}

/**
 * @title   NativeUniqueDepositAddress
 * @notice  A proxy contract that allows users to have unique eth deposit addresses for HTLC swaps
 *          Clone will not exist until the user deposits funds to the predetermined address.
 * @dev     This contract is cloned for each new deposit address and initialized with swap parameters
 */
contract NativeUniqueDepositAddress is Initializable {
    using Clones for address;
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice  Initializes the proxy contract with HTLC swap parameters, and initiates
     *          the atomic swap. The happy flow of this contract ends when this gets called.
     */
    function initialize() public initializer {
        (
            address _nativeHTLC,
            address _refundAddress,
            address _redeemer,
            uint256 timelock,
            bytes32 secretHash,
            uint256 amount,
            bytes memory destinationData
        ) = getArgs();
        NativeHTLC(_nativeHTLC).initiateOnBehalf{value: amount}(
            payable(_refundAddress), payable(_redeemer), timelock, amount, secretHash, destinationData
        );
    }

    /**
     * @dev     Fetches the arguments passed during contract cloning.
     * @return  refundAddress   The refund/recovery address that will be able to refund the swap/recover accidental funds sent to the UDA.
     * @return  redeemer        The address that can redeem the swap with the secret.
     * @return  timelock        The number of blocks before the refund address can reclaim the funds.
     * @return  secretHash      The hash of the secret required for redemption.
     * @return  amount          The amount to swap.
     */
    function getArgs() internal view returns (address, address, address, uint256, bytes32, uint256, bytes memory) {
        bytes memory args = address(this).fetchCloneArgs();
        return abi.decode(args, (address, address, address, uint256, bytes32, uint256, bytes));
    }

    /**
     * @notice  Allows the owner to recover any tokens accidentally sent to this contract
     * @dev     Always sends the funds to the owner (refundAddress) of the contract
     *          NOTE: Publicly callable by anyone. This is intentional/safe because destination is hardcoded.
     * @param   _token  The ERC20 token to recover
     */
    function recover(address _token) public {
        (, address refundAddress,,,,,) = getArgs();
        IERC20(_token).safeTransfer(refundAddress, IERC20(_token).balanceOf(address(this)));
    }

    /**
     * @notice  Allows the owner to recover any eth accidentally sent to this contract
     * @dev     Always sends the funds to the owner (refundAddress) of the contract
     *          NOTE: Publicly callable by anyone. This is intentional/safe because destination is hardcoded.
     */
    function recover() public {
        (, address _refundAddress,,,,,) = getArgs();
        payable(_refundAddress).transfer(address(this).balance);
    }
}
