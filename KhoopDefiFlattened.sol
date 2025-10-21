// SPDX-License-Identifier: MIT
pragma solidity =0.8.20 >=0.4.16 >=0.6.2 ^0.8.20;

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

// lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}

// src/KhoopDefi.sol

/**
 * @title KhoopDefi - Sequential Round-Robin Distribution
 * @notice Referral & team earn: 1x at purchase + cycles 1,2,3 (NOT cycle 4)
 * @dev Total 4 payments per slot: purchase + first 3 cycles only
 */
contract KhoopDefi is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Errors ============
    error KhoopDefi__ExceedsTransactionLimit();
    error KhoopDefi__InsufficientBalance();
    error KhoopDefi__SelfReferral();
    error KhoopDefi__UnregisteredReferrer();
    error KhoopDefi__ZeroAddress();
    error KhoopDefi__InCooldown();
    error KhoopDefi__MustPayExactAmount();
    error KhoopDefi__CooldownNotActive();
    error KhoopDefi__UserNotRegistered();
    error KhoopDefi__UserAlreadyRegistered();
    error KhoopDefi__NoActiveCycles();
    error KhoopDefi__InvalidAmount();
    error KhoopDefi__CannotRegisterForAnotherUser();

    // ============ Types ============
    struct User {
        address referrer;
        uint256 totalEntriesPurchased;
        uint256 totalCyclesCompleted;
        uint256 referrerBonusEarned;
        uint256 referrerBonusMissed;
        uint256 totalEarnings;
        uint256 totalReferrals;
        uint256 cooldownEnd;
        bool isRegistered;
        bool isActive;
    }

    struct Entry {
        uint256 entryId;
        address owner;
        uint256 purchaseTimestamp;
        uint8 cyclesCompleted;
        uint256 lastCycleTimestamp;
        bool isActive;
    }

    struct GlobalStats {
        uint256 totalUsers;
        uint256 totalActiveUsers;
        uint256 totalEntriesPurchased;
        uint256 totalReferrerBonusPaid;
        uint256 totalReferrerBonusMissed;
        uint256 totalPayoutsMade;
        uint256 totalCyclesCompleted;
        uint256 totalSlotsRemaining;
    }

    // ============ Constants ============
    uint256 private constant GAS_BUFFER = 120_000;
    uint256 private constant MAX_GAS_PER_ITERATION = 700_000;
    uint256 private constant MAX_ITERATIONS_PER_CALL = 50;
    uint256 private constant CORE_TEAM_SHARE = 15e16;
    uint256 private constant INVESTORS_SHARE = 2e16;
    uint256 private constant CONTINGENCY_SHARE = 1e17;
    uint256 private constant ENTRY_COST = 15e18;
    uint256 private constant CYCLE_PAYOUT = 5e18;
    uint256 private constant MAX_CYCLES_PER_ENTRY = 4;
    uint256 private constant LAST_CYCLE = 4;
    uint256 private constant MAX_ENTRIES_PER_TX = 20;
    uint256 private constant REFERRER_ENTRY_BONUS = 1e18;
    uint256 private constant COOLDOWN_PERIOD = 30 minutes;
    uint256 private constant REDUCED_COOLDOWN = 15 minutes;
    uint256 private constant COOLDOWN_FEE = 5e17;
    uint256 private constant TOTAL_TEAM_SHARE = (CORE_TEAM_SHARE * 4) + (INVESTORS_SHARE * 15) + CONTINGENCY_SHARE;

    // ============ Immutable State Variables ============
    IERC20 public immutable usdt;
    address[4] public coreTeamWallet;
    address[15] public investorsWallet;
    address public immutable reserveWallet;
    address public immutable powerCycleWallet;

    // ============ Mappings ============
    mapping(address => User) public users;
    mapping(uint256 => Entry) public entries;
    mapping(address => uint256[]) public userEntries;
    mapping(address => address[]) public userReferrals;

    // Queue management
    uint256[] public entryQueue;
    uint256 public nextEntryIndex;

    // ============ Global Tracking ============
    GlobalStats public globalStats;
    uint256 public nextEntryId = 1;
    uint256 private teamAccumulatedBalance;
    uint256 private accumulatedCoolDownFee;

    // ============ Events ============
    event EntryPurchased(uint256 indexed entryId, address indexed user, address indexed referrer, uint256 amount);
    event CycleCompleted(uint256 indexed entryId, address indexed user, uint8 cycleNumber, uint256 payoutAmount);
    event EntryMaxedOut(uint256 indexed entryId, address indexed user);
    event ReferralAdded(address indexed referrer, address indexed referred);
    event ReferrerBonusPaid(address indexed referrer, address indexed referred, uint256 amount);
    event UserRegistered(address indexed user, address indexed referrer);
    event BatchEntryPurchased(uint256 startId, uint256 endId, address indexed user, uint256 totalCost);
    event CooldownReduced(address indexed user, uint256 feePaid);
    event TeamSharesDistributed(uint256 totalAmount);
    event CyclesProcessed(uint256 count, uint256 totalPaid);
    event SystemDonation(address indexed donor, uint256 amount);
    event EmergencyWithdraw(address indexed donor, uint256 amount);
    event ReferralBonusSkipped(uint256 indexed entryId, address indexed referrer);

    // ============ Constructor ============
    constructor(
        address[4] memory _coreTeam,
        address[15] memory _investors,
        address _reserve,
        address _powerCycle,
        address _usdt
    ) Ownable(msg.sender) {
        if (_reserve == address(0) || _powerCycle == address(0) || _usdt == address(0)) {
            revert KhoopDefi__ZeroAddress();
        }

        for (uint256 i = 0; i < 4; i++) {
            if (_coreTeam[i] == address(0)) revert KhoopDefi__ZeroAddress();
            coreTeamWallet[i] = _coreTeam[i];
        }

        for (uint256 i = 0; i < 15; i++) {
            if (_investors[i] == address(0)) revert KhoopDefi__ZeroAddress();
            investorsWallet[i] = _investors[i];
        }

        reserveWallet = _reserve;
        powerCycleWallet = _powerCycle;
        usdt = IERC20(_usdt);

        users[powerCycleWallet] = User({
            referrer: address(0),
            totalEntriesPurchased: 0,
            totalCyclesCompleted: 0,
            referrerBonusEarned: 0,
            referrerBonusMissed: 0,
            totalEarnings: 0,
            totalReferrals: 0,
            cooldownEnd: 0,
            isRegistered: true,
            isActive: true
        });
        globalStats.totalUsers++;
        globalStats.totalActiveUsers++;
        emit UserRegistered(powerCycleWallet, address(0));
    }

    // ============ External Functions ============

    function registerUser(address user, address referrer) external {
        if (user != msg.sender) revert KhoopDefi__CannotRegisterForAnotherUser();
        if (user == referrer) revert KhoopDefi__SelfReferral();
        if (users[user].isRegistered) revert KhoopDefi__UserAlreadyRegistered();
        if (referrer != address(0) && !users[referrer].isRegistered) {
            revert KhoopDefi__UnregisteredReferrer();
        }

        users[user] = User({
            referrer: referrer,
            totalEntriesPurchased: 0,
            totalCyclesCompleted: 0,
            referrerBonusEarned: 0,
            referrerBonusMissed: 0,
            totalEarnings: 0,
            totalReferrals: 0,
            cooldownEnd: 0,
            isRegistered: true,
            isActive: false
        });

        if (referrer != address(0)) {
            userReferrals[referrer].push(user);
            users[referrer].totalReferrals++;
            emit ReferralAdded(referrer, user);
        }

        globalStats.totalUsers++;
        emit UserRegistered(user, referrer);
    }

    function purchaseEntries(uint256 numEntries) external nonReentrant {
        if (!users[msg.sender].isRegistered) revert KhoopDefi__UserNotRegistered();
        if (numEntries == 0 || numEntries > MAX_ENTRIES_PER_TX) {
            revert KhoopDefi__ExceedsTransactionLimit();
        }
        if (users[msg.sender].cooldownEnd != 0 && block.timestamp < users[msg.sender].cooldownEnd) {
            revert KhoopDefi__InCooldown();
        }

        uint256 totalCost = ENTRY_COST * numEntries;
        if (usdt.balanceOf(msg.sender) < totalCost) revert KhoopDefi__MustPayExactAmount();

        uint256 startId = nextEntryId;

        usdt.safeTransferFrom(msg.sender, address(this), totalCost);

        address userReferrer = users[msg.sender].referrer;
        bool isReferrerActive = (userReferrer != address(0)) && users[userReferrer].isActive;

        for (uint256 i = 0; i < numEntries; i++) {
            _createEntry(msg.sender);

            // Check for missed initial referral bonus
            if (userReferrer != address(0) && !isReferrerActive) {
                users[userReferrer].referrerBonusMissed += REFERRER_ENTRY_BONUS;
                globalStats.totalReferrerBonusMissed += REFERRER_ENTRY_BONUS;
                emit ReferralBonusSkipped(nextEntryId - 1, userReferrer);
            }
        }

        if (!users[msg.sender].isActive) {
            _updateUserActiveStatus(msg.sender);
        }
        users[msg.sender].totalEntriesPurchased += numEntries;
        users[msg.sender].cooldownEnd = block.timestamp + COOLDOWN_PERIOD;
        globalStats.totalEntriesPurchased += numEntries;

        _processAvailableCycles();

        emit BatchEntryPurchased(startId, nextEntryId - 1, msg.sender, totalCost);
    }

    function reduceCooldown() external nonReentrant {
        User storage user = users[msg.sender];

        if (user.cooldownEnd == 0) revert KhoopDefi__CooldownNotActive();
        if (block.timestamp >= user.cooldownEnd) revert KhoopDefi__CooldownNotActive();
        if (usdt.balanceOf(msg.sender) < COOLDOWN_FEE) revert KhoopDefi__InsufficientBalance();

        usdt.safeTransferFrom(msg.sender, address(this), COOLDOWN_FEE);
        accumulatedCoolDownFee += COOLDOWN_FEE;
        uint256 newCooldownEnd = block.timestamp + REDUCED_COOLDOWN;
        user.cooldownEnd = newCooldownEnd >= user.cooldownEnd ? block.timestamp : newCooldownEnd;

        emit CooldownReduced(msg.sender, COOLDOWN_FEE);
    }

    function completeCycles() external nonReentrant {
        uint256 processed = _processAvailableCycles();
        if (processed == 0) revert KhoopDefi__NoActiveCycles();
    }

    function donateToSystem(uint256 amount) external nonReentrant {
        if (amount == 0) revert KhoopDefi__InvalidAmount();
        if (usdt.balanceOf(msg.sender) < amount) revert KhoopDefi__InsufficientBalance();

        usdt.safeTransferFrom(msg.sender, address(this), amount);
        emit SystemDonation(msg.sender, amount);
        _processAvailableCycles();
    }

    function processCyclesBatch(uint256 iterations) external nonReentrant returns (uint256) {
        uint256 processed = _processCyclesManual(iterations);

        if (processed > 0) {
            emit CyclesProcessed(processed, processed * CYCLE_PAYOUT);
        }

        return processed;
    }

    function emergencyWithdraw(uint256 amount) external nonReentrant onlyOwner {
        if (amount == 0) revert KhoopDefi__InvalidAmount();
        if (usdt.balanceOf(address(this)) < amount) revert KhoopDefi__InsufficientBalance();

        usdt.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    // ============ Internal Functions ============

    function _createEntry(address user) internal {
        uint256 entryId = nextEntryId;

        entries[entryId] = Entry({
            entryId: entryId,
            owner: user,
            purchaseTimestamp: block.timestamp,
            cyclesCompleted: 0,
            lastCycleTimestamp: block.timestamp,
            isActive: true
        });

        userEntries[user].push(entryId);
        entryQueue.push(entryId);

        globalStats.totalSlotsRemaining += MAX_CYCLES_PER_ENTRY;

        address userReferrer = users[user].referrer;
        if (userReferrer != address(0) && users[userReferrer].isActive) {
            _payReferralBonus(userReferrer, REFERRER_ENTRY_BONUS, user);
        }
        _distributeTeamShares();

        emit EntryPurchased(entryId, user, userReferrer, ENTRY_COST);
        nextEntryId++;
    }

    function _payReferralBonus(address referrer, uint256 amount, address referred) internal {
        users[referrer].referrerBonusEarned += amount;
        globalStats.totalReferrerBonusPaid += amount;
        usdt.safeTransfer(referrer, amount);
        emit ReferrerBonusPaid(referrer, referred, amount);
    }

    function _distributeTeamShares() internal {
        uint256 totalCorePerWallet = CORE_TEAM_SHARE;
        uint256 totalInvestorPerWallet = INVESTORS_SHARE;
        uint256 totalContingency = CONTINGENCY_SHARE;

        for (uint256 i = 0; i < 4; i++) {
            usdt.safeTransfer(coreTeamWallet[i], totalCorePerWallet);
        }

        for (uint256 i = 0; i < 15; i++) {
            usdt.safeTransfer(investorsWallet[i], totalInvestorPerWallet);
        }

        usdt.safeTransfer(reserveWallet, totalContingency);

        uint256 totalDistributed = (totalCorePerWallet * 4) + (totalInvestorPerWallet * 15) + totalContingency;
        teamAccumulatedBalance += totalDistributed;
        emit TeamSharesDistributed(totalDistributed);
    }

    function _processAvailableCycles() internal returns (uint256 totalCyclesProcessed) {
        if (entryQueue.length == 0) return 0;

        uint256 balance = usdt.balanceOf(address(this));
        uint256 minGas = 50_000;
        uint256 totalEntries = entryQueue.length;
        uint256 startGas = gasleft();

        uint256 maxIterations = (startGas - GAS_BUFFER) / MAX_GAS_PER_ITERATION;
        if (maxIterations > MAX_ITERATIONS_PER_CALL) {
            maxIterations = MAX_ITERATIONS_PER_CALL;
        }

        uint256 iterations = 0;

        while (iterations < maxIterations && gasleft() > GAS_BUFFER) {
            uint256 entryId = entryQueue[nextEntryIndex];
            Entry storage entry = entries[entryId];

            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                bool isLastCycle = (entry.cyclesCompleted + 1 == LAST_CYCLE);

                address userReferrer = users[entry.owner].referrer;
                bool shouldPayReferrer = !isLastCycle && userReferrer != address(0) && users[userReferrer].isActive;

                bool shouldPayTeam = !isLastCycle;

                uint256 requiredBalance = CYCLE_PAYOUT;
                if (shouldPayReferrer) requiredBalance += REFERRER_ENTRY_BONUS;
                if (shouldPayTeam) requiredBalance += TOTAL_TEAM_SHARE;

                if (balance < requiredBalance) {
                    break;
                }

                if (shouldPayTeam) {
                    _distributeTeamShares();
                }
                if (shouldPayReferrer) {
                    _payReferralBonus(userReferrer, REFERRER_ENTRY_BONUS, entry.owner);
                } else if (!isLastCycle && userReferrer != address(0) && !users[userReferrer].isActive) {
                    users[userReferrer].referrerBonusMissed += REFERRER_ENTRY_BONUS;
                    globalStats.totalReferrerBonusMissed += REFERRER_ENTRY_BONUS;
                    emit ReferralBonusSkipped(entryId, userReferrer);
                }

                // Update entry and user stats
                entry.cyclesCompleted++;
                entry.lastCycleTimestamp = block.timestamp;
                users[entry.owner].totalCyclesCompleted++;
                users[entry.owner].totalEarnings += CYCLE_PAYOUT;
                globalStats.totalCyclesCompleted++;
                globalStats.totalPayoutsMade += CYCLE_PAYOUT;
                globalStats.totalSlotsRemaining--;

                // Pay cycle payout to entry owner
                usdt.safeTransfer(entry.owner, CYCLE_PAYOUT);
                balance -= requiredBalance;
                totalCyclesProcessed++;

                emit CycleCompleted(entryId, entry.owner, entry.cyclesCompleted, CYCLE_PAYOUT);

                // Check if entry completed all cycles
                if (entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
                    entry.isActive = false;
                    _updateUserActiveStatus(entry.owner);
                    emit EntryMaxedOut(entryId, entry.owner);
                }
            }

            // Move to next entry in queue (circular)
            nextEntryIndex = (nextEntryIndex + 1) % totalEntries;
            iterations++;
        }

        if (totalCyclesProcessed > 0) {
            emit CyclesProcessed(totalCyclesProcessed, totalCyclesProcessed * CYCLE_PAYOUT);
        }

        return totalCyclesProcessed;
    }

    function _processCyclesManual(uint256 maxIterations) internal returns (uint256 totalCyclesProcessed) {
        if (entryQueue.length == 0) return 0;

        uint256 balance = usdt.balanceOf(address(this));
        uint256 minGas = 50_000;
        uint256 totalEntries = entryQueue.length;
        uint256 iterations = 0;

        while (iterations < maxIterations && gasleft() > minGas) {
            uint256 entryId = entryQueue[nextEntryIndex];
            Entry storage entry = entries[entryId];

            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                bool isLastCycle = (entry.cyclesCompleted + 1 == LAST_CYCLE);

                address userReferrer = users[entry.owner].referrer;
                bool shouldPayReferrer = !isLastCycle && userReferrer != address(0) && users[userReferrer].isActive;

                bool shouldPayTeam = !isLastCycle;

                uint256 requiredBalance = CYCLE_PAYOUT;
                if (shouldPayReferrer) requiredBalance += REFERRER_ENTRY_BONUS;
                if (shouldPayTeam) requiredBalance += TOTAL_TEAM_SHARE;

                if (balance < requiredBalance) {
                    break;
                }

                if (shouldPayTeam) {
                    _distributeTeamShares();
                }
                if (shouldPayReferrer) {
                    _payReferralBonus(userReferrer, REFERRER_ENTRY_BONUS, entry.owner);
                } else if (!isLastCycle && userReferrer != address(0) && !users[userReferrer].isActive) {
                    users[userReferrer].referrerBonusMissed += REFERRER_ENTRY_BONUS;
                    globalStats.totalReferrerBonusMissed += REFERRER_ENTRY_BONUS;
                    emit ReferralBonusSkipped(entryId, userReferrer);
                }

                entry.cyclesCompleted++;
                entry.lastCycleTimestamp = block.timestamp;
                users[entry.owner].totalCyclesCompleted++;
                users[entry.owner].totalEarnings += CYCLE_PAYOUT;
                globalStats.totalCyclesCompleted++;
                globalStats.totalPayoutsMade += CYCLE_PAYOUT;
                globalStats.totalSlotsRemaining--;

                usdt.safeTransfer(entry.owner, CYCLE_PAYOUT);
                balance -= requiredBalance;
                totalCyclesProcessed++;

                emit CycleCompleted(entryId, entry.owner, entry.cyclesCompleted, CYCLE_PAYOUT);

                if (entry.cyclesCompleted >= MAX_CYCLES_PER_ENTRY) {
                    entry.isActive = false;
                    _updateUserActiveStatus(entry.owner);
                    emit EntryMaxedOut(entryId, entry.owner);
                }
            }

            nextEntryIndex = (nextEntryIndex + 1) % totalEntries;
            iterations++;
        }

        return totalCyclesProcessed;
    }

    function _hasPendingCycles(address user) internal view returns (bool) {
        uint256[] storage userSlots = userEntries[user];

        for (uint256 i = 0; i < userSlots.length; i++) {
            Entry storage entry = entries[userSlots[i]];
            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                return true;
            }
        }

        return false;
    }

    function _updateUserActiveStatus(address user) internal {
        bool hasActiveEntries = false;
        uint256[] storage userEntryIds = userEntries[user];

        for (uint256 i = 0; i < userEntryIds.length; i++) {
            Entry storage entry = entries[userEntryIds[i]];
            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                hasActiveEntries = true;
                break;
            }
        }

        if (users[user].isActive != hasActiveEntries) {
            users[user].isActive = hasActiveEntries;
            if (hasActiveEntries) {
                globalStats.totalActiveUsers++;
            } else {
                globalStats.totalActiveUsers--;
            }
        }
    }

    // ============ View Functions ============

    function getUserAllEntries(address user) external view returns (uint256[] memory) {
        return userEntries[user];
    }

    function isUserActive(address user) external view returns (bool) {
        return users[user].isActive;
    }

    function getContractBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function getTeamAccumulatedBalance() external view returns (uint256) {
        return teamAccumulatedBalance;
    }

    function getCooldownRemaining(address user) external view returns (uint256) {
        if (users[user].cooldownEnd == 0 || block.timestamp >= users[user].cooldownEnd) {
            return 0;
        }
        return users[user].cooldownEnd - block.timestamp;
    }

    function getAccumulatedCoolDownFee() external view returns (uint256) {
        return accumulatedCoolDownFee;
    }

    function userHasPendingCycles(address user) external view returns (bool) {
        return _hasPendingCycles(user);
    }

    function getQueueLength() external view returns (uint256) {
        return entryQueue.length;
    }

    function getNextInLine()
        external
        view
        returns (uint256 entryId, address owner, uint8 cyclesCompleted, uint8 cyclesRemaining, bool isActive)
    {
        uint256 totalEntries = entryQueue.length;
        if (totalEntries == 0) return (0, address(0), 0, 0, false);

        uint256 currentId = entryQueue[nextEntryIndex];
        Entry storage entry = entries[currentId];

        if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
            return (
                currentId, entry.owner, entry.cyclesCompleted, uint8(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted), true
            );
        }

        uint256 nextValidIndex = (nextEntryIndex + 1) % totalEntries;
        for (uint256 i = 0; i < totalEntries; i++) {
            currentId = entryQueue[nextValidIndex];
            entry = entries[currentId];

            if (entry.isActive && entry.cyclesCompleted < MAX_CYCLES_PER_ENTRY) {
                return (
                    currentId,
                    entry.owner,
                    entry.cyclesCompleted,
                    uint8(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted),
                    true
                );
            }

            nextValidIndex = (nextValidIndex + 1) % totalEntries;
        }

        return (0, address(0), 0, 0, false);
    }

    function getPendingCyclesCount() external view returns (uint256 totalPendingCycles) {
        return globalStats.totalSlotsRemaining;
    }

    function getEntryDetails(uint256 entryId)
        external
        view
        returns (
            address owner,
            uint256 purchaseTime,
            uint8 cyclesCompleted,
            uint256 lastCycleTime,
            bool isActive,
            uint8 cyclesRemaining
        )
    {
        Entry storage entry = entries[entryId];
        require(entry.entryId != 0, "Entry does not exist");

        return (
            entry.owner,
            entry.purchaseTimestamp,
            entry.cyclesCompleted,
            entry.lastCycleTimestamp,
            entry.isActive,
            entry.isActive ? uint8(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted) : 0
        );
    }

    function getUserStats(address user)
        external
        view
        returns (
            uint256 totalEntriesPurchased,
            uint256 totalCyclesCompleted,
            uint256 referrerBonusEarned,
            uint256 referrerBonusMissed,
            uint256 totalEarnings,
            uint256 totalReferrals,
            bool isActive
        )
    {
        User storage userStats = users[user];
        return (
            userStats.totalEntriesPurchased,
            userStats.totalCyclesCompleted,
            userStats.referrerBonusEarned,
            userStats.referrerBonusMissed,
            userStats.totalEarnings,
            userStats.totalReferrals,
            userStats.isActive
        );
    }

    function getGlobalStats()
        external
        view
        returns (
            uint256 totalUsers,
            uint256 totalActiveUsers,
            uint256 totalEntriesPurchased,
            uint256 totalReferrerBonusPaid,
            uint256 totalReferrerBonusMissed,
            uint256 totalPayoutsMade,
            uint256 totalCyclesCompleted,
            uint256 totalSlotsRemaining
        )
    {
        return (
            globalStats.totalUsers,
            globalStats.totalActiveUsers,
            globalStats.totalEntriesPurchased,
            globalStats.totalReferrerBonusPaid,
            globalStats.totalReferrerBonusMissed,
            globalStats.totalPayoutsMade,
            globalStats.totalCyclesCompleted,
            globalStats.totalSlotsRemaining
        );
    }

    function getUserActiveEntries(address user) external view returns (uint256[] memory) {
        uint256[] memory userEntryIds = userEntries[user];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < userEntryIds.length; i++) {
            if (entries[userEntryIds[i]].isActive) {
                activeCount++;
            }
        }

        uint256[] memory activeEntries = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < userEntryIds.length; i++) {
            if (entries[userEntryIds[i]].isActive) {
                activeEntries[index] = userEntryIds[i];
                index++;
            }
        }

        return activeEntries;
    }

    function getUserPotentialEarnings(address user) external view returns (uint256) {
        uint256[] memory userEntryIds = userEntries[user];
        uint256 potential = 0;

        for (uint256 i = 0; i < userEntryIds.length; i++) {
            Entry storage entry = entries[userEntryIds[i]];
            if (entry.isActive) {
                uint256 remainingCycles = uint256(MAX_CYCLES_PER_ENTRY - entry.cyclesCompleted);
                potential += (remainingCycles * CYCLE_PAYOUT);
            }
        }

        return potential;
    }

    function getInactiveReferrals(address referrer) external view returns (address[] memory) {
        address[] storage referrals = userReferrals[referrer];
        uint256 totalReferrals = referrals.length;
        address[] memory tempInactive = new address[](totalReferrals);
        uint256 inactiveCount = 0;

        for (uint256 i = 0; i < totalReferrals; i++) {
            if (!users[referrals[i]].isActive) {
                tempInactive[inactiveCount] = referrals[i];
                inactiveCount++;
            }
        }

        address[] memory inactiveReferrals = new address[](inactiveCount);
        for (uint256 i = 0; i < inactiveCount; i++) {
            inactiveReferrals[i] = tempInactive[i];
        }

        return inactiveReferrals;
    }
}

