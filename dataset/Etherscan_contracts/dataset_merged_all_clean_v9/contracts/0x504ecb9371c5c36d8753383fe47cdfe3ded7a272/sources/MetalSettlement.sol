// SPDX-License-Identifier: MIT

/*
    METAL — MetalSettlement
    Inter-institutional settlement: institutional-grade compliance executes
    provably and instantly during on-chain settlement. Atomic delivery-versus-
    payment (DvP) of two tokenized legs, gated by the ComplianceRegistry.

    Website:  https://metalntwx.com/
    Twitter:  https://x.com/metalntwx
*/

pragma solidity 0.8.26;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface ICompliance {
    function canSettle(address a, address b) external view returns (bool);
}

contract MetalSettlement {
    address public owner;
    address public compliance; // optional ComplianceRegistry; address(0) disables checks

    enum Status { None, Open, Settled, Cancelled }

    struct Trade {
        address partyA;     // delivers assetA, receives assetB
        address partyB;     // delivers assetB, receives assetA
        address assetA;
        address assetB;
        uint256 amountA;
        uint256 amountB;
        Status status;
    }

    uint256 public tradeCount;
    mapping(uint256 => Trade) public trades;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ComplianceSet(address indexed compliance);
    event TradeOpened(uint256 indexed id, address indexed partyA, address indexed partyB);
    event TradeSettled(uint256 indexed id);
    event TradeCancelled(uint256 indexed id);

    error NotAuthorized();
    error BadState();
    error ComplianceBlocked();
    error TransferFailed();

    constructor(address owner_, address compliance_) {
        owner = owner_;
        compliance = compliance_;
        emit OwnershipTransferred(address(0), owner_);
        emit ComplianceSet(compliance_);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setCompliance(address compliance_) external onlyOwner {
        compliance = compliance_;
        emit ComplianceSet(compliance_);
    }

    /// @notice Open a DvP trade. Both legs settle atomically in `settle`.
    function openTrade(
        address partyB,
        address assetA,
        uint256 amountA,
        address assetB,
        uint256 amountB
    ) external returns (uint256 id) {
        id = ++tradeCount;
        trades[id] = Trade({
            partyA: msg.sender,
            partyB: partyB,
            assetA: assetA,
            assetB: assetB,
            amountA: amountA,
            amountB: amountB,
            status: Status.Open
        });
        emit TradeOpened(id, msg.sender, partyB);
    }

    /// @notice Atomically swap the two legs. Either party may trigger once both
    ///         have approved this contract for their respective leg.
    function settle(uint256 id) external {
        Trade storage t = trades[id];
        if (t.status != Status.Open) revert BadState();
        if (msg.sender != t.partyA && msg.sender != t.partyB) revert NotAuthorized();

        if (compliance != address(0)) {
            if (!ICompliance(compliance).canSettle(t.partyA, t.partyB)) revert ComplianceBlocked();
        }

        t.status = Status.Settled;

        // provably atomic: both legs move or the whole tx reverts
        if (!IERC20(t.assetA).transferFrom(t.partyA, t.partyB, t.amountA)) revert TransferFailed();
        if (!IERC20(t.assetB).transferFrom(t.partyB, t.partyA, t.amountB)) revert TransferFailed();

        emit TradeSettled(id);
    }

    function cancel(uint256 id) external {
        Trade storage t = trades[id];
        if (t.status != Status.Open) revert BadState();
        if (msg.sender != t.partyA && msg.sender != t.partyB) revert NotAuthorized();
        t.status = Status.Cancelled;
        emit TradeCancelled(id);
    }
}
