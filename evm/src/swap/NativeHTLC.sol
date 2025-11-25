// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
 * @author  Garden Finance
 * @title   HTLC smart contract for atomic swaps
 * @notice  Any signer can create an order to serve as one of either halves of a cross chain
 *          atomic swap for any user with respective valid signatures.
 * @dev     The contract can be used to create an order to serve as the the commitment for two
 *          types of users :
 *          Initiator functions: 1. initiate
 *                               2. initiateOnBehalf
 *                               3. refund
 *                               4. instantRefund
 *
 *          Redeemer function:   1. redeem
 */
contract NativeHTLC is EIP712 {
    struct Order {
        address payable initiator;
        address payable redeemer;
        uint256 initiatedAt;
        uint256 timelock;
        uint256 amount;
        uint256 fulfilledAt;
    }

    address public constant token = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    string public constant name = "HTLC";
    string public constant version = "3";

    mapping(bytes32 => Order) public orders;

    bytes32 private constant _REFUND_TYPEHASH = keccak256("Refund(bytes32 orderId)");

    event Initiated(bytes32 indexed orderID, bytes32 indexed secretHash, uint256 indexed amount);
    event InitiatedWithDestinationData(
        bytes32 indexed orderID, bytes32 indexed secretHash, uint256 indexed amount, bytes destinationData
    );
    event Redeemed(bytes32 indexed orderID, bytes32 indexed secretHash, bytes secret);
    event Refunded(bytes32 indexed orderID);

    //0x63cf1fac
    error NativeHTLC__ZeroAddressInitiator();
    //0x64c7ce67
    error NativeHTLC__ZeroAddressRedeemer();
    //0x2907afb8
    error NativeHTLC__ZeroTimelock();
    //0x0e3e0208
    error NativeHTLC__ZeroAmount();
    //0x71e76dc2
    error NativeHTLC__OrderNotInitiated();
    //0x38258a2d
    error NativeHTLC__OrderFulfilled();
    //0xe3358152
    error NativeHTLC__IncorrectSecret();
    //0x221bb10a
    error NativeHTLC__OrderNotExpired();
    //0xb67261d3
    error NativeHTLC__SameInitiatorAndRedeemer();
    //0x850c33e1
    error NativeHTLC__DuplicateOrder();
    //0x98fa56bc
    error NativeHTLC__InvalidRedeemerSignature();
    //0xa6fe390b
    error NativeHTLC__IncorrectFundsRecieved();
    //0x5e1dd837
    error NativeHTLC__SameFunderAndRedeemer();

    /**
     * @notice  .
     * @dev     provides checks to ensure
     *              1. redeemer is not null address
     *              2. timelock is greater than 0
     *              3. amount param is greater than 0
     *              4. initiator != redeemer
     *              5. funds sent are equal to the amount param
     * @param   initiator public address of the initiator
     * @param   redeemer  public address of the reedeem
     * @param   timelock  timelock in blocks for the htlc order
     * @param   amount  amount of tokens to trade
     */
    modifier safeParams(address initiator, address redeemer, uint256 timelock, uint256 amount) {
        require(redeemer != address(0), NativeHTLC__ZeroAddressRedeemer());
        require(initiator != redeemer, NativeHTLC__SameInitiatorAndRedeemer());
        require(timelock > 0, NativeHTLC__ZeroTimelock());
        require(amount > 0, NativeHTLC__ZeroAmount());
        require(msg.value == amount, NativeHTLC__IncorrectFundsRecieved());
        _;
    }

    constructor() EIP712(name, version) {}

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
    function initiate(address payable redeemer, uint256 timelock, uint256 amount, bytes32 secretHash)
        external
        payable
        safeParams(msg.sender, redeemer, timelock, amount)
    {
        _initiate(payable(msg.sender), redeemer, timelock, secretHash);
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
     * @param   destinationData  additional data to be used for redemption
     */
    function initiate(
        address payable redeemer,
        uint256 timelock,
        uint256 amount,
        bytes32 secretHash,
        bytes calldata destinationData
    ) external payable safeParams(msg.sender, redeemer, timelock, amount) {
        bytes32 orderID = _initiate(payable(msg.sender), redeemer, timelock, secretHash);
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
    function initiateOnBehalf(
        address payable initiator,
        address payable redeemer,
        uint256 timelock,
        uint256 amount,
        bytes32 secretHash
    ) external payable safeParams(initiator, redeemer, timelock, amount) {
        require(msg.sender != redeemer, NativeHTLC__SameFunderAndRedeemer());
        require(initiator != address(0), NativeHTLC__ZeroAddressInitiator());
        _initiate(initiator, redeemer, timelock, secretHash);
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
     * @param   destinationData  additional data to be used for redemption
     */
    function initiateOnBehalf(
        address payable initiator,
        address payable redeemer,
        uint256 timelock,
        uint256 amount,
        bytes32 secretHash,
        bytes calldata destinationData
    ) external payable safeParams(initiator, redeemer, timelock, amount) {
        require(msg.sender != redeemer, NativeHTLC__SameFunderAndRedeemer());
        require(initiator != address(0), NativeHTLC__ZeroAddressInitiator());
        bytes32 orderID = _initiate(initiator, redeemer, timelock, secretHash);
        emit InitiatedWithDestinationData(orderID, secretHash, amount, destinationData);
    }

    /**
     * @notice  Signers with correct secret to an order's secret hash can redeem to claim the locked
     *          token
     * @dev     Signers are not allowed to redeem an order with wrong secret or redeem the same order
     *          multiple times
     * @param   orderID  orderId of the htlc order
     * @param   secret  secret used to redeem the order
     */
    function redeem(bytes32 orderID, bytes calldata secret) external {
        require(secret.length == 32, NativeHTLC__IncorrectSecret());
        Order storage order = orders[orderID];

        address payable orderRedeemer = order.redeemer;
        require(orderRedeemer != address(0), NativeHTLC__OrderNotInitiated());

        require(order.fulfilledAt == 0, NativeHTLC__OrderFulfilled());

        bytes32 secretHash = sha256(secret);
        uint256 amount = order.amount;

        require(
            sha256(
                abi.encode(
                    block.chainid, secretHash, order.initiator, orderRedeemer, order.timelock, amount, address(this)
                )
            ) == orderID,
            NativeHTLC__IncorrectSecret()
        );

        order.fulfilledAt = block.number;

        emit Redeemed(orderID, secretHash, secret);

        // NOTE: .transfer() uses 2300 gas stipend. This is safe against reentrancy but may fail 
        // for some smart contract wallets. This is an intentional design choice favoring security.
        orderRedeemer.transfer(amount);
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
        require(timelock > 0, NativeHTLC__OrderNotInitiated());

        require(order.fulfilledAt == 0, NativeHTLC__OrderFulfilled());
        // NOTE: Strict inequality '<' means refund is available at block (initiatedAt + timelock + 1).
        require(order.initiatedAt + timelock < block.number, NativeHTLC__OrderNotExpired());

        order.fulfilledAt = block.number;

        emit Refunded(orderID);

        order.initiator.transfer(order.amount);
    }

    /**
     * @notice  Internal function to initiate an order for an atomic swap
     * @dev     This function is called internally to create a new order for an atomic swap.
     *          It checks that there is no duplicate order.
     *          It creates a new order with the provided parameters and stores it in the 'orders' mapping.
     *          It emits an 'Initiated' event with the order ID, secret hash, amount and executable flag.
     *          It transfers the specified amount of tokens from the initiator to the contract address.
     * @param   initiator_   The address of the initiator of the atomic swap
     * @param   redeemer_   The address of the redeemer of the atomic swap
     * @param   timelock_     The timelock block number for the atomic swap
     * @param   secretHash_ The hash of the secret used for redemption
     */
    function _initiate(address payable initiator_, address payable redeemer_, uint256 timelock_, bytes32 secretHash_)
        internal
        returns (bytes32 orderID)
    {
        // NOTE: OrderID excludes msg.sender (funder). Initiator controls the order.
        orderID =
            sha256(abi.encode(block.chainid, secretHash_, initiator_, redeemer_, timelock_, msg.value, address(this)));

        require(orders[orderID].timelock == 0, NativeHTLC__DuplicateOrder());

        orders[orderID] = Order({
            initiator: initiator_,
            redeemer: redeemer_,
            initiatedAt: block.number,
            timelock: timelock_,
            amount: msg.value,
            fulfilledAt: 0
        });

        emit Initiated(orderID, secretHash_, msg.value);
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
        require(order.fulfilledAt == 0, NativeHTLC__OrderFulfilled());

        address payable orderRedeemer = order.redeemer;

        if (msg.sender != orderRedeemer) {
            bytes32 instantRefundHash = instantRefundDigest(orderID);
            require(
                SignatureChecker.isValidSignatureNow(orderRedeemer, instantRefundHash, signature),
                NativeHTLC__InvalidRedeemerSignature()
            );
        }

        order.fulfilledAt = block.number;

        emit Refunded(orderID);

        order.initiator.transfer(order.amount);
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
