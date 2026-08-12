// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev ERC20 代币的标准极简接口
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title NPH 团队代币锁仓合约 (12-Month Cliff, 48-Month Linear)
 * @notice 专为 BNHP 团队代币锁仓设计。
 * @dev 100% 去信任化（Trustless）设计，无管理员权限（No Owner），一旦部署规则永久锁死。
 * 
 * 规则：
 * 1. 锁仓代币：NPH 代币（总量的 15% 充入此合约）。
 * 2. 受益人：0x433edf18c307e4a5767ead3d4e377daf2ae38621 (团队多签钱包)。
 * 3. 悬崖期 (Cliff)：自部署开始之日起 12 个月（365 天）。在悬崖期内，可提取代币数量为 0。
 * 4. 释放期 (Duration)：自部署开始之日起 48 个月（4 * 365 天）纯线性释放。
 * 5. 悬崖期满后，受益人可以随时调用 release() 提取已解锁的代币。
 */
contract NPHTeamVesting {
    // 受益人地址：团队多签钱包 (Safe)
    address public constant BENEFICIARY = 0x433Edf18C307e4A5767ead3D4e377Daf2Ae38621;
    
    // NPH 代币合约地址（部署后在构造函数中填入，支持灵活性）
    IERC20 public immutable token;
    
    // 锁仓开始时间（Unix 时间戳）
    uint256 public immutable start;
    
    // 悬崖期结束时间（部署后 12 个月）
    uint256 public immutable cliff;
    
    // 线性释放总时长（48 个月）
    uint256 public immutable duration;
    
    // 已经提取的代币数量
    uint256 public released;

    // 提取事件
    event TokensReleased(address indexed beneficiary, uint256 amount);

    /**
     * @param _tokenAddress NPH 代币的智能合约地址
     * @param _startTimestamp 锁仓开始时间戳（传入 0 则默认以当前部署区块时间 block.timestamp 开始）
     */
    constructor(address _tokenAddress, uint256 _startTimestamp) {
        require(_tokenAddress != address(0), "Token is zero address");
        
        token = IERC20(_tokenAddress);
        
        // 如果传入 0，则以当前部署区块时间为起点
        uint256 actualStart = _startTimestamp == 0 ? block.timestamp : _startTimestamp;
        start = actualStart;
        
        // 12 个月悬崖期 (365 天)
        cliff = actualStart + 365 days;
        
        // 48 个月线性释放总时长 (4 * 365 天)
        duration = 4 * 365 days;
    }

    /**
     * @notice 计算当前累计已解锁的代币总量
     */
    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        // 合约当前代币余额 + 已经提取的代币数量 = 锁仓代币总额
        uint256 totalBalance = token.balanceOf(address(this)) + released;

        if (timestamp < cliff) {
            return 0; // 12个月 Cliff 期内，解锁量为 0
        } else if (timestamp >= start + duration) {
            return totalBalance; // 48个月释放期满，全额解锁
        } else {
            // 12个月 Cliff 期满后，按照已过去的时间进行纯线性计算
            return (totalBalance * (timestamp - start)) / duration;
        }
    }

    /**
     * @notice 提取已解锁的代币
     * @dev 只有受益人（团队多签钱包）可以调用此函数。Gas 费极低（约 45k Gas）。
     */
    function release() external {
        require(msg.sender == BENEFICIARY, "Only beneficiary can release");
        
        uint256 vested = vestedAmount(block.timestamp);
        uint256 unreleased = vested - released;
        
        require(unreleased > 0, "No tokens due for release");
        
        released += unreleased;
        require(token.transfer(BENEFICIARY, unreleased), "Token transfer failed");
        
        emit TokensReleased(BENEFICIARY, unreleased);
    }
}
