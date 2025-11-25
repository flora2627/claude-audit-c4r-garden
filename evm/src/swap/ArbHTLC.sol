// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

interface ArbSys {
    function arbBlockNumber() external view returns (uint256);
}

/**
 * @author  Garden Finance
 * @title   HTLC smart contract for atomic swaps
 * @notice  Any signer can create an order to serve as one of either halves of a cross chain
 *          atomic swap for any user with respective valid signatures.
 * @dev     The contract can be used to create an order to serve as the the commitment for two
 *          types of users :
 *          Initiator functions: 1. initiate
 *                               2. initiateOnBehalf
 *                               3. initiateWithSignature
 *                               4. refund
 *                               5. instantRefund
 *
 *          Redeemer function:   1. redeem
 */
contract ArbHTLC is EIP712 {
    using SafeERC20 for IERC20;

    struct Order {
        address initiator;
        address redeemer;
        uint256 initiatedAt;
        uint256 timelock;
        uint256 amount;
        uint256 fulfilledAt;
    }

    IERC20 public token;
    uint256 public isInitialized;

    string public constant name = "HTLC";
    string public constant version = "3";

    mapping(bytes32 => Order) public orders;

    bytes32 private constant _INITIATE_TYPEHASH =
        keccak256("Initiate(address redeemer,uint256 timelock,uint256 amount,bytes32 secretHash)");

    bytes32 private constant _REFUND_TYPEHASH = keccak256("Refund(bytes32 orderId)");

    address constant ARBSYS_ADDR = 0x0000000000000000000000000000000000000064;

    event Initiated(bytes32 indexed orderID, bytes32 indexed secretHash, uint256 indexed amount);
    event InitiatedWithDestinationData(
        bytes32 indexed orderID, bytes32 indexed secretHash, uint256 indexed amount, bytes destinationData
    );
    event Redeemed(bytes32 indexed orderID, bytes32 indexed secretHash, bytes secret);
    event Refunded(bytes32 indexed orderID);

    //0x800568f0
    error ArbHTLC__ZeroAddressRedeemer();
    //0x893b04a3
    error ArbHTLC__ZeroTimelock();
    //0xdcc830bf
    error ArbHTLC__ZeroAmount();
    //0x693989cc
    error ArbHTLC__OrderNotInitiated();
    //0xa7dc33de
    error ArbHTLC__OrderFulfilled();
    //0xdc5114b6
    error ArbHTLC__IncorrectSecret();
    //0xcadc2009
    error ArbHTLC__OrderNotExpired();
    //0x8dd00073
    error ArbHTLC__SameInitiatorAndRedeemer();
    //0xee1b963b
    error ArbHTLC__DuplicateOrder();
    //0x8a587036
    error ArbHTLC__InvalidRedeemerSignature();
    //0x5a779308
    error ArbHTLC__SameFunderAndRedeemer();
    //0x4a471281
    error ArbHTLC__ZeroAddressInitiator();
    //0xffdca751
    error ArbHTLC__InvalidInitiatorSignature();
    //0x9b08da28
    error ArbHTLC__HTLCAlreadyInitialized();

    /**
     * @notice  .
     * @dev     provides checks to ensure
     *              1. initiator and redeemer are not the same address
     *              2. redeemer is not null address
     *              3. timelock is greater than 0
     *              4. amount is greater than zero
     * @param   initiator  public address of the initiator
     * @param   redeemer  public address of the redeemer
     * @param   timelock  timelock in blocks for the htlc order
     * @param   amount  amount of tokens to trade
     */
    modifier safeParams(address initiator, address redeemer, uint256 timelock, uint256 amount) {
        require(initiator != redeemer, ArbHTLC__SameInitiatorAndRedeemer());
        require(redeemer != address(0), ArbHTLC__ZeroAddressRedeemer());
        require(timelock > 0, ArbHTLC__ZeroTimelock());
        require(amount > 0, ArbHTLC__ZeroAmount());
        _;
    }

    constructor() EIP712(name, version) {}

    function initialise(address _token) public {
        // AUDIT: No access control - callable by anyone. Single-use only (isInitialized flag).
        // Front-running risk exists but requires HTLCRegistry owner to fail verification before addHTLC().
        // System assumes centralized owner will verify token address - NOT a vulnerability under trust model.
        require(isInitialized == 0, ArbHTLC__HTLCAlreadyInitialized());
        token = IERC20(_token);
        unchecked {
            isInitialized++;
        }
    }

    /**
     * @notice  Signers can create an order with order params
     * @dev     Secret used to generate secret hash for initiation should be generated randomly
     *          and sha256 hash should be used to support hashing methods on other non-evm chains.
     *          Signers cannot generate orders with same secret hash or override an existing order.
     * @param   redeemer  public address of the redeemer
     * @param   timelock  timelock in blocks for the htlc order
     * @param   amount  amount of tokens to trade
     * @param   secretHash  sha256 hash of the secret used for redemption
     */
    function initiate(address redeemer, uint256 timelock, uint256 amount, bytes32 secretHash)
        external
        safeParams(msg.sender, redeemer, timelock, amount)
    {
        _initiate(msg.sender, msg.sender, redeemer, timelock, amount, secretHash);
    }

    /**
     * @notice  Signers can create an order with order params
     * @dev     Secret used to generate secret hash for initiation should be generated randomly
     *          and sha256 hash should be used to support hashing methods on other non-evm chains.
     *          Signers cannot generate orders with same secret hash or override an existing order.
     * @param   redeemer  public address of the redeemer
     * @param   timelock  timelock in blocks for the htlc order
     * @param   amount  amount of tokens to trade
     * @param   secretHash  sha256 hash of the secret used for redemption
     * @param   destinationData  additional data to be used by the redeemer
     */
    function initiate(
        address redeemer,
        uint256 timelock,
        uint256 amount,
        bytes32 secretHash,
        bytes calldata destinationData
    ) external safeParams(msg.sender, redeemer, timelock, amount) {
        bytes32 orderID = _initiate(msg.sender, msg.sender, redeemer, timelock, amount, secretHash);
        emit InitiatedWithDestinationData(orderID, secretHash, amount, destinationData);
    }

    /**
     * @notice  Signers can create an order with order params
     * @dev     Secret used to generate secret hash for initiation should be generated randomly
     *          and sha256 hash should be used to support hashing methods on other non-evm chains.
     *          Signers cannot generate orders with same secret hash or override an existing order.
     * @param   initiator  public address of the initiator
     * @param   redeemer  public address of the redeemer
     * @param   timelock  timelock in blocks for the htlc order
     * @param   amount  amount of tokens to trade
     * @param   secretHash  sha256 hash of the secret used for redemption
     */
    function initiateOnBehalf(address initiator, address redeemer, uint256 timelock, uint256 amount, bytes32 secretHash)
        external
        safeParams(initiator, redeemer, timelock, amount)
    {
        require(msg.sender != redeemer, ArbHTLC__SameFunderAndRedeemer());
        require(initiator != address(0), ArbHTLC__ZeroAddressInitiator());
        _initiate(msg.sender, initiator, redeemer, timelock, amount, secretHash);
    }

    /**
     * @notice  Signers can create an order with order params
     * @dev     Secret used to generate secret hash for initiation should be generated randomly
     *          and sha256 hash should be used to support hashing methods on other non-evm chains.
     *          Signers cannot generate orders with same secret hash or override an existing order.
     * @param   initiator  public address of the initiator
     * @param   redeemer  public address of the redeemer
     * @param   timelock  timelock in blocks for the htlc order
     * @param   amount  amount of tokens to trade
     * @param   secretHash  sha256 hash of the secret used for redemption
     * @param   destinationData  additional data to be used by the redeemer
     */
    function initiateOnBehalf(
        address initiator,
        address redeemer,
        uint256 timelock,
        uint256 amount,
        bytes32 secretHash,
        bytes calldata destinationData
    ) external safeParams(initiator, redeemer, timelock, amount) {
        require(msg.sender != redeemer, ArbHTLC__SameFunderAndRedeemer());
        require(initiator != address(0), ArbHTLC__ZeroAddressInitiator());
        bytes32 orderID = _initiate(msg.sender, initiator, redeemer, timelock, amount, secretHash);
        emit InitiatedWithDestinationData(orderID, secretHash, amount, destinationData);
    }

    /**
     * @notice  Signers can create an order with order params and signature for a user
     * @dev     Secret used to generate secret hash for initiation should be generated randomly
     *          and sha256 hash should be used to support hashing methods on other non-evm chains.
     *          Signers cannot generate orders with same secret hash or override an existing order.
     * @param   initiator public address of the initiator
     * @param   redeemer  public address of the redeemer
     * @param   timelock  timelock in blocks for the htlc order
     * @param   amount  amount of tokens to trade
     * @param   secretHash  sha256 hash of the secret used for redemption
     * @param   signature  EIP712 signature provided by user for initiation; user will be assigned as initiator
     *
     */
    function initiateWithSignature(
        address initiator,
        address redeemer,
        uint256 timelock,
        uint256 amount,
        bytes32 secretHash,
        bytes calldata signature
    ) external safeParams(initiator, redeemer, timelock, amount) {
        bytes32 hash =
            _hashTypedDataV4(keccak256(abi.encode(_INITIATE_TYPEHASH, redeemer, timelock, amount, secretHash)));

        require(SignatureChecker.isValidSignatureNow(initiator, hash, signature), ArbHTLC__InvalidInitiatorSignature());
        _initiate(initiator, initiator, redeemer, timelock, amount, secretHash);
    }

    /**
     * @notice  Signers with correct secret to an order's secret hash can redeem the locked
     *          tokens
     * @dev     Signers are not allowed to redeem an order with wrong secret or redeem the same order
     *          multiple times
     * @param   orderID  orderId of the htlc order
     * @param   secret  secret used to redeem an order
     */
    function redeem(bytes32 orderID, bytes calldata secret) external {
        require(secret.length == 32, ArbHTLC__IncorrectSecret());
        Order storage order = orders[orderID];

        address redeemer = order.redeemer;
        require(redeemer != address(0), ArbHTLC__OrderNotInitiated());

        require(order.fulfilledAt == 0, ArbHTLC__OrderFulfilled());

        bytes32 secretHash = sha256(secret);
        uint256 amount = order.amount;

        require(
            sha256(
                abi.encode(block.chainid, secretHash, order.initiator, redeemer, order.timelock, amount, address(this))
            ) == orderID,
            ArbHTLC__IncorrectSecret()
        );

        order.fulfilledAt = ArbSys(ARBSYS_ADDR).arbBlockNumber();

        emit Redeemed(orderID, secretHash, secret);

        token.safeTransfer(redeemer, amount);
    }

    /**
     * @notice  Signers can refund the locked assets after timelock block number
     * @dev     Signers cannot refund the order before expiry block number or refund the same order
     *          multiple times.
     *          Funds will be SafeTransferred to the initiator.
     * @param   orderID  orderId of the htlc order
     */
    function refund(bytes32 orderID) external {
        Order storage order = orders[orderID];

        uint256 timelock = order.timelock;
        require(timelock > 0, ArbHTLC__OrderNotInitiated());

        require(order.fulfilledAt == 0, ArbHTLC__OrderFulfilled());
        require(order.initiatedAt + timelock < ArbSys(ARBSYS_ADDR).arbBlockNumber(), ArbHTLC__OrderNotExpired());

        order.fulfilledAt = ArbSys(ARBSYS_ADDR).arbBlockNumber();

        emit Refunded(orderID);

        token.safeTransfer(order.initiator, order.amount);
    }

    /**
     * @notice  Internal function to initiate an order for an atomic swap
     * @dev     This function is called internally to create a new order for an atomic swap.
     *          It checks that there is no duplicate order.
     *          It creates a new order with the provided parameters and stores it in the 'orders' mapping.
     *          It emits an 'Initiated' event with the order ID, secret hash, amount and executable flag.
     *          It transfers the specified amount of tokens from the initiator to the contract address.
     * @param   funder_  The address of the funder of the atomic swap
     * @param   initiator_   The address of the initiator of the atomic swap
     * @param   redeemer_   The address of the redeemer of the atomic swap
     * @param   timelock_     The timelock block number for the atomic swap
     * @param   amount_     The amount of tokens to be traded in the atomic swap
     * @param   secretHash_ The hash of the secret used for redemption
     */
    function _initiate(
        address funder_,
        address initiator_,
        address redeemer_,
        uint256 timelock_,
        uint256 amount_,
        bytes32 secretHash_
    ) internal returns (bytes32 orderID) {
        orderID =
            sha256(abi.encode(block.chainid, secretHash_, initiator_, redeemer_, timelock_, amount_, address(this)));

        require(orders[orderID].timelock == 0, ArbHTLC__DuplicateOrder());

        orders[orderID] = Order({
            initiator: initiator_,
            redeemer: redeemer_,
            initiatedAt: ArbSys(ARBSYS_ADDR).arbBlockNumber(),
            timelock: timelock_,
            amount: amount_,
            fulfilledAt: 0
        });

        emit Initiated(orderID, secretHash_, amount_);

        token.safeTransferFrom(funder_, address(this), amount_);
    }

    /**
     * @notice  Redeemers can let initiator refund the locked assets before expiry block number
     * @dev     Signers cannot refund the same order multiple times.
     *          Funds will be SafeTransferred to the initiator.
     *
     * @param orderID       orderID of the htlc order
     * @param signature     EIP712 signature provided by redeemer for instant refund.
     */
    function instantRefund(bytes32 orderID, bytes calldata signature) external {
        Order storage order = orders[orderID];
        require(order.fulfilledAt == 0, ArbHTLC__OrderFulfilled());

        address orderRedeemer = order.redeemer;
        if (msg.sender != orderRedeemer) {
            bytes32 instantRefundHash = instantRefundDigest(orderID);
            require(
                SignatureChecker.isValidSignatureNow(orderRedeemer, instantRefundHash, signature),
                ArbHTLC__InvalidRedeemerSignature()
            );
        }

        order.fulfilledAt = ArbSys(ARBSYS_ADDR).arbBlockNumber();

        emit Refunded(orderID);

        token.safeTransfer(order.initiator, order.amount);
    }

    /**
     * @notice  Calculates the digest for instant refund signatures
     * @dev     Uses EIP712 typed data hashing to generate digest that should be signed by redeemer
     *          to allow instant refund before timelock expiry
     * @param   orderID  The order ID for which instant refund is being requested
     * @return  bytes32  The digest that should be signed by redeemer
     */
    function instantRefundDigest(bytes32 orderID) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(_REFUND_TYPEHASH, orderID)));
    }
}
