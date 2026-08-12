// SPDX-License-Identifier: MIT
/*
  UNHOOK — FEE SPLITTER

  Optional treasury target. If you point UnhookToken.treasury at this contract,
  swept ETH + UNHOOK fees land here and get split across a fixed set of recipients
  by immutable share weights (basis points, must sum to 10000).

  Trust properties:
   - shares and recipients are set ONCE at deploy and can never change
   - there is no owner, no setter, no withdraw-all backdoor
   - anyone can trigger a release; funds can ONLY go to the preset recipients in
     the preset proportions (integer-division dust stays for the next release)

  NOT audited, no value.
*/
pragma solidity 0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract UnhookFeeSplitter {
    address[] public recipients;
    uint256[] public sharesBps;          // parallel to recipients; sum == TOTAL_BPS
    uint256 public constant TOTAL_BPS = 10_000;

    event EthReleased(uint256 total);
    event TokenReleased(address indexed token, uint256 total);

    constructor(address[] memory _recipients, uint256[] memory _sharesBps) {
        require(_recipients.length == _sharesBps.length && _recipients.length > 0, "len");
        uint256 sum;
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "zero recipient");
            require(_sharesBps[i] > 0, "zero share");
            sum += _sharesBps[i];
        }
        require(sum == TOTAL_BPS, "shares != 10000");
        recipients = _recipients;
        sharesBps  = _sharesBps;
    }

    function recipientsCount() external view returns (uint256) { return recipients.length; }

    /// @notice Split the contract's current ETH balance to recipients by share.
    function releaseEth() public {
        uint256 bal = address(this).balance;
        if (bal == 0) return;
        uint256 n = recipients.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 amt = (bal * sharesBps[i]) / TOTAL_BPS;
            if (amt > 0) {
                (bool ok,) = recipients[i].call{value: amt}("");
                require(ok, "eth send");
            }
        }
        emit EthReleased(bal);
    }

    /// @notice Split the contract's current balance of `token` to recipients by share.
    function releaseToken(address token) public {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) return;
        uint256 n = recipients.length;
        for (uint256 i = 0; i < n; i++) {
            uint256 amt = (bal * sharesBps[i]) / TOTAL_BPS;
            if (amt > 0) require(IERC20(token).transfer(recipients[i], amt), "token send");
        }
        emit TokenReleased(token, bal);
    }

    receive() external payable {}
}