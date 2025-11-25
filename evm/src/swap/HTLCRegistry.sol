// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./HTLC.sol";
import "./NativeHTLC.sol";
import {NativeUniqueDepositAddress, UniqueDepositAddress} from "./UDA.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title HTLCRegistry
 * @dev   This contract manages HTLCs (Hash Time-Locked Contracts) and Unique Deposit Addresses (UDAs) for native and ERC20 tokens.
 *        It allows the deployment and management of HTLCs for both native ETH and ERC20 tokens, as well as managing the associated UDAs.
 *        The contract also enables the updating of implementation addresses for the UDAs and HTLCs.
 */
contract HTLCRegistry is Ownable {
    using Clones for address;
    using Address for address;

    error HTLCRegistry__InvalidAddressParameters();
    error HTLCRegistry__ZeroTimelock();
    error HTLCRegistry__ZeroAmount();
    error HTLCRegistry__InvalidAddress();
    error HTLCRegistry__InsufficientFundsDeposited();
    error HTLCRegistry__NoNativeHTLCFound();
    error HTLCRegistry__HTLCTokenMismatch();
    error HTLCRegistry__ZeroHTLCAddress();

    event HTLCAdded(address indexed htlc, address indexed token);
    event UDACreated(address indexed addressUDA, address indexed refundAddress, address indexed htlc);
    event NativeUDACreated(address indexed addressNativeUDA, address indexed refundAddress);
    event UDAImplUpdated(address indexed impl);
    event NativeUDAImplUpdated(address indexed impl);

    // to get native HTLC, pass nativeTokenAddress (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) as the key
    mapping(address token => address HTLC) public htlcs;

    string public constant name = "HTLCRegistry";
    string public constant version = "1.0.0";
    address public implUDA;
    address public implNativeUDA;
    address public constant nativeTokenAddress = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    constructor(address owner) Ownable(owner) {
        implUDA = address(new UniqueDepositAddress());
    }

    /**
     * @notice  Modifier to validate the parameters used for HTLC and UDA creation
     * @dev     Ensures that the redeemer, refundAddress, and timelock parameters are valid
     * @param   refundAddress   The public address of the user who will receive the refund
     * @param   redeemer    The public address of the redeemer
     * @param   timelock    The timelock block number for the atomic swap
     * @param   amount      The amount of tokens to trade
     */
    modifier safeParams(address refundAddress, address redeemer, uint256 timelock, uint256 amount) {
        require(
            redeemer != address(0) && refundAddress != address(0) && refundAddress != redeemer,
            HTLCRegistry__InvalidAddressParameters()
        );
        require(timelock > 0, HTLCRegistry__ZeroTimelock());
        require(amount > 0, HTLCRegistry__ZeroAmount());
        _;
    }

    /**
     * @notice  Modifier to ensure a valid contract address is passed
     * @dev     Reverts the transaction if the address provided does not have associated bytecode
     * @param   _addr   The address to check
     */
    modifier validContractAddress(address _addr) {
        require(_addr.code.length != 0, HTLCRegistry__InvalidAddress());
        _;
    }

    /**
     * @notice  Allows eth UDA implementation to be updated
     * @dev     Setter function to update the NativeUDA implementation to the provided address
     *          Permissioned function that can only be called by the owner of the contract
     * @notice  Be absolutely certain that the address passed is correct
     * @param   _impl  The address of the UDA implementation contract
     */
    function setImplNativeUDA(address _impl) external onlyOwner validContractAddress(_impl) {
        implNativeUDA = _impl;
        emit NativeUDAImplUpdated(_impl);
    }

    /**
     * @notice  Allows ERC20 UDA implementation to be updated
     * @dev     Setter function to update the UDA implementation to the new address
     *          Permissioned function that can only be called by the owner of the contract
     * @notice  Be absolutely certain that the address passed is correct
     * @param   _impl  The address of the UDA implementation contract
     */
    function setImplUDA(address _impl) external onlyOwner validContractAddress(_impl) {
        implUDA = _impl;
        emit UDAImplUpdated(_impl);
    }

    /**
     * @notice  Allows the addition of previously deployed HTLCs to the registry
     * @dev     Maps the given HTLC address to its respective token in the registry
     *          Permissioned function that can only be called by the owner of the contract
     * @param   _htlc   The htlc address to be added to the registry
     */
    function addHTLC(address _htlc) external onlyOwner validContractAddress(_htlc) {
        address token = address(HTLC(_htlc).token());
        htlcs[token] = _htlc;
        emit HTLCAdded(_htlc, token);
    }

    /**
     * @notice  Deploys a new UDA clone for an ERC20 token, and calls the initialize call on the UDA,
     *          which in turn begins the swap by calling the initiateOnBehalf() in the correspoding HTLC
     * @dev     Clones the UDA to the predetermined address returned by the _getERC20Address() function
     *          Initializes the UDA clone, which calls the initiateOnBehalf() on the HTLC
     *          Swap params are passed to the UDA while cloning, accessible thorugh the clone's bytecode
     * @notice  Can only be successfully called once sufficient funds are deposited to the predetermined address
     * @param   htlc            The HTLC being used in the swap
     * @param   refundAddress   Address to recover accidental funds sent to the UDA
     * @param   redeemer        Redeemer's address to be used for the swap
     * @param   timelock        The timelock to be used for the swap
     * @param   secretHash      The secret hash to lock the funds
     * @param   amount          The amount to be used for the swap
     */
    function createERC20SwapAddress(
        address htlc,
        address refundAddress,
        address redeemer,
        uint256 timelock,
        bytes32 secretHash,
        uint256 amount,
        bytes calldata destinationData
    ) external returns (address) {
        require(htlc != address(0), HTLCRegistry__ZeroHTLCAddress());
        require(htlcs[address(HTLC(htlc).token())] == htlc, HTLCRegistry__HTLCTokenMismatch());

        bytes memory encodedArgs =
            abi.encode(htlc, refundAddress, redeemer, timelock, secretHash, amount, destinationData);
        bytes32 salt = keccak256(
            abi.encodePacked(refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData))
        );
        address _implUDA = implUDA;

        // getting the ERC20SwapAddress
        address addr = _implUDA.predictDeterministicAddressWithImmutableArgs(encodedArgs, salt);
        require(IERC20(HTLC(htlc).token()).balanceOf(addr) >= amount, HTLCRegistry__InsufficientFundsDeposited());

        if (addr.code.length == 0) {
            address uda = _implUDA.cloneDeterministicWithImmutableArgs(encodedArgs, salt);
            emit UDACreated(address(uda), address(refundAddress), htlc);
            uda.functionCall(abi.encodeCall(UniqueDepositAddress.initialize, ()));
        }

        return addr;
    }

    /**
     * @dev     calculate the counterfactual address of this account as it would be returned by createAccount()
     * @notice  this address must be used to deposit the funds into, before calling the createERC20SwapAddress() function
     * @notice  CRITICAL: This address depends on the current `implUDA`. If `implUDA` changes between
     *          calling this and calling `createERC20SwapAddress`, the predicted address will change,
     *          leaving funds stuck at the old predicted address.
     * @param   htlc            The HTLC being used in the swap
     * @param   refundAddress   Address to recover accidental funds sent to the UDA
     * @param   redeemer        Redeemer's address to be used for the swap
     * @param   timelock        The timelock to be used for the swap
     * @param   secretHash      The secret hash to lock the funds
     * @param   amount          The amount to be used for the swap
     */
    function getERC20Address(
        address htlc,
        address refundAddress,
        address redeemer,
        uint256 timelock,
        bytes32 secretHash,
        uint256 amount,
        bytes calldata destinationData
    ) external view safeParams(refundAddress, redeemer, timelock, amount) returns (address) {
        require(htlc != address(0), HTLCRegistry__ZeroHTLCAddress());
        require(htlcs[address(HTLC(htlc).token())] == htlc, HTLCRegistry__HTLCTokenMismatch());

        return implUDA.predictDeterministicAddressWithImmutableArgs(
            abi.encode(htlc, refundAddress, redeemer, timelock, secretHash, amount, destinationData),
            keccak256(
                abi.encodePacked(
                    refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData)
                )
            )
        );
    }

    /**
     * @notice  Deploys a new UDA clone for Eth, and calls the initialize call on the UDA,
     *          which in turn begins the swap by calling the initiateOnBehalf() in the nativeEth HTLC
     * @dev     Clones the UDA to the predetermined address returned by the _getNativeAddress() function
     *          Initializes the UDA clone, which calls the initiateOnBehalf() on the HTLC
     *          Swap params are passed to the UDA while cloning, accessible thorugh the clone's bytecode
     * @notice  Can only be successfully called once sufficient funds are deposited to the predetermined address
     * @param   refundAddress   Address to recover accidental funds sent to the UDA
     * @param   redeemer        Redeemer's address to be used for the swap
     * @param   timelock        The timelock to be used for the swap
     * @param   secretHash      The secret hash to lock the funds
     * @param   amount          The amount to be used for the swap
     */
    function createNativeSwapAddress(
        address refundAddress,
        address redeemer,
        uint256 timelock,
        bytes32 secretHash,
        uint256 amount,
        bytes calldata destinationData
    ) external returns (address) {
        address nativeHTLC = htlcs[nativeTokenAddress];
        require(nativeHTLC != address(0), HTLCRegistry__NoNativeHTLCFound());

        bytes memory encodedArgs =
            abi.encode(nativeHTLC, refundAddress, redeemer, timelock, secretHash, amount, destinationData);
        bytes32 salt = keccak256(
            abi.encodePacked(refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData))
        );
        address _implNativeUDA = implNativeUDA;

        // getting Native swap address
        address addr = implNativeUDA.predictDeterministicAddressWithImmutableArgs(encodedArgs, salt);
        require(address(addr).balance >= amount, HTLCRegistry__InsufficientFundsDeposited());

        if (addr.code.length == 0) {
            address nativeUda = _implNativeUDA.cloneDeterministicWithImmutableArgs(encodedArgs, salt);
            emit NativeUDACreated(address(nativeUda), address(refundAddress));
            nativeUda.functionCall(abi.encodeCall(NativeUniqueDepositAddress.initialize, ()));
        }
        return addr;
    }

    /**
     * @dev     calculate the counterfactual address of this account as it would be returned by createAccount()
     * @notice  this address must be used to deposit the funds into, before calling the createNativeSwapAddress() function
     * @notice  CRITICAL: This address depends on the current `implNativeUDA`. If `implNativeUDA` changes between
     *          calling this and calling `createNativeSwapAddress`, the predicted address will change,
     *          leaving funds stuck at the old predicted address.
     * @param   refundAddress   Address to recover accidental funds sent to the UDA
     * @param   redeemer        Redeemer's address to be used for the swap
     * @param   timelock        The timelock to be used for the swap
     * @param   secretHash      The secret hash to lock the funds
     * @param   amount          The amount to be used for the swap
     */
    function getNativeAddress(
        address refundAddress,
        address redeemer,
        uint256 timelock,
        bytes32 secretHash,
        uint256 amount,
        bytes calldata destinationData
    ) external view safeParams(refundAddress, redeemer, timelock, amount) returns (address) {
        address nativeHTLC = htlcs[nativeTokenAddress];
        require(nativeHTLC != address(0), HTLCRegistry__NoNativeHTLCFound());

        return implNativeUDA.predictDeterministicAddressWithImmutableArgs(
            abi.encode(nativeHTLC, refundAddress, redeemer, timelock, secretHash, amount, destinationData),
            keccak256(
                abi.encodePacked(
                    refundAddress, redeemer, timelock, secretHash, amount, abi.encodePacked(destinationData)
                )
            )
        );
    }
}
