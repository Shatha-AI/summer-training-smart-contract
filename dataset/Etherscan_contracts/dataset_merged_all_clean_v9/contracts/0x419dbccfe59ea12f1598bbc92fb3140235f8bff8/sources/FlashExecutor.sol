// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.35;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC1363 is IERC20, IERC165 {
    function transferAndCall(address to, uint256 value) external returns (bool);

    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    function approveAndCall(address spender, uint256 value) external returns (bool);

    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

library SafeERC20 {
    error SafeERC20FailedOperation(address token);

    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        if (!_safeApprove(token, spender, value, false)) {
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }

    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

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

    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)

            if iszero(and(success, eq(mload(0x00), 1))) {
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }

                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0x00, 0x64, 0x00, 0x20)

            if iszero(and(success, eq(mload(0x00), 1))) {
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }

                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            mstore(0x60, 0)
        }
    }

    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(spender, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)

            if iszero(and(success, eq(mload(0x00), 1))) {
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0x00, returndatasize())
                    revert(fmp, returndatasize())
                }

                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }
}

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function supplyCollateral(
        MarketParams calldata marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external;
}

interface IAaveV3Pool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IMorphoSupplyCollateralCallback {
    function onMorphoSupplyCollateral(uint256 assets, bytes calldata data) external;
}

interface IAaveFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IAaveFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

contract FlashExecutor is
    IMorphoFlashLoanCallback,
    IMorphoSupplyCollateralCallback,
    IAaveFlashLoanSimpleReceiver,
    IAaveFlashLoanReceiver
{
    using SafeERC20 for IERC20;

    struct Call {
        address target;
        bytes data;
        uint256 value;
        bool skipRevert;
    }

    address public immutable admin;
    IMorpho public immutable morpho;
    address public immutable aaveV3Pool;
    address public immutable sparkPool;

    mapping(address => bool) internal isCaller;

    mapping(address => bool) public isTargetAllowlisted;

    address[] internal _targetList;

    mapping(address => uint256) internal _targetIndex;

    bytes32 private transient expectedCallbackHash;
    address private transient expectedCallbackSender;

    bool private transient _executing;

    uint256 private constant _MAX_RETURN_COPY = 256;

    event CallerSet(address indexed caller, bool allowed);
    event TargetSet(address indexed target, bool allowed);
    event Swept(address indexed token, address indexed to, uint256 amount);
    event CallSkipped(uint256 indexed index, address indexed target, bytes returnData);

    error Unauthorized();
    error NotCaller();
    error TargetNotAllowed(address target);
    error UnexpectedSender();
    error UnexpectedCallback();
    error UnexpectedInitiator();
    error AssetMismatch();
    error AmountMismatch();
    error MorphoNotConfigured();
    error AaveV3NotConfigured();
    error SparkNotConfigured();
    error CallbackNotInvoked();
    error ZeroAddress();
    error UnsolicitedEth();
    error EthSweepFailed();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    modifier onlyCaller() {
        if (!isCaller[msg.sender]) revert NotCaller();
        _;
    }

    modifier executing() {
        bool prev = _executing;
        _executing = true;
        _;
        _executing = prev;
    }

    constructor(
        address _admin,
        address _morpho,
        address _aaveV3Pool,
        address _sparkPool,
        address[] memory initialCallers
    ) {
        if (_admin == address(0)) revert ZeroAddress();
        admin = _admin;
        morpho = IMorpho(_morpho);
        aaveV3Pool = _aaveV3Pool;
        sparkPool = _sparkPool;
        for (uint256 i; i < initialCallers.length; ++i) {
            address c = initialCallers[i];
            if (c == address(0)) revert ZeroAddress();
            isCaller[c] = true;
        }
    }

    function setCaller(address caller, bool allowed) external onlyAdmin {
        if (caller == address(0)) revert ZeroAddress();
        isCaller[caller] = allowed;
        emit CallerSet(caller, allowed);
    }

    function isCallerAllowlisted(address caller) external view returns (bool) {
        return isCaller[caller];
    }

    function setTarget(address target, bool allowed) external onlyAdmin {
        if (target == address(0)) revert ZeroAddress();
        bool current = isTargetAllowlisted[target];
        if (allowed && !current) {
            isTargetAllowlisted[target] = true;
            _targetList.push(target);
            _targetIndex[target] = _targetList.length;
            emit TargetSet(target, true);
        } else if (!allowed && current) {
            isTargetAllowlisted[target] = false;
            uint256 idx = _targetIndex[target] - 1;
            uint256 last = _targetList.length - 1;
            if (idx != last) {
                address swapped = _targetList[last];
                _targetList[idx] = swapped;
                _targetIndex[swapped] = idx + 1;
            }
            _targetList.pop();
            delete _targetIndex[target];
            emit TargetSet(target, false);
        }
    }

    function getAllowlistedTargets() external view returns (address[] memory) {
        return _targetList;
    }

    function targetAllowlistCount() external view returns (uint256) {
        return _targetList.length;
    }

    function sweep(address token, address to, uint256 amount) external onlyAdmin {
        if (token == address(0)) {
            (bool ok, ) = to.call{value: amount}("");
            if (!ok) revert EthSweepFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        emit Swept(token, to, amount);
    }

    function execute(Call[] calldata calls) external payable onlyCaller executing {
        _runCalls(calls);
    }

    function executeWithMorphoFlashLoan(
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (address(morpho) == address(0)) revert MorphoNotConfigured();

        bytes memory data = abi.encode(token, amount, calls);
        expectedCallbackHash = keccak256(data);
        expectedCallbackSender = address(morpho);

        morpho.flashLoan(token, amount, data);

        if (expectedCallbackHash != bytes32(0)) revert CallbackNotInvoked();
    }

    function executeWithAaveV3FlashLoan(
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (aaveV3Pool == address(0)) revert AaveV3NotConfigured();
        _runAaveFlashLoan(aaveV3Pool, token, amount, calls);
    }

    function executeWithSparkFlashLoan(
        address token,
        uint256 amount,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (sparkPool == address(0)) revert SparkNotConfigured();
        _runAaveFlashLoan(sparkPool, token, amount, calls);
    }

    function executeWithAaveV3FlashLoanMode2(
        address debtAsset,
        uint256 amount,
        address onBehalfOf,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (aaveV3Pool == address(0)) revert AaveV3NotConfigured();
        _runAaveFlashLoanMode2(aaveV3Pool, debtAsset, amount, onBehalfOf, calls);
    }

    function executeWithSparkFlashLoanMode2(
        address debtAsset,
        uint256 amount,
        address onBehalfOf,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (sparkPool == address(0)) revert SparkNotConfigured();
        _runAaveFlashLoanMode2(sparkPool, debtAsset, amount, onBehalfOf, calls);
    }

    function executeWithMorphoSupplyCollateral(
        MarketParams calldata marketParams,
        uint256 collateralAmount,
        address onBehalf,
        Call[] calldata calls
    ) external onlyCaller executing {
        if (address(morpho) == address(0)) revert MorphoNotConfigured();

        bytes memory data = abi.encode(marketParams.collateralToken, collateralAmount, calls);
        expectedCallbackHash = keccak256(data);
        expectedCallbackSender = address(morpho);

        morpho.supplyCollateral(marketParams, collateralAmount, onBehalf, data);

        if (expectedCallbackHash != bytes32(0)) revert CallbackNotInvoked();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != expectedCallbackSender) revert UnexpectedSender();
        if (keccak256(data) != expectedCallbackHash) revert UnexpectedCallback();

        address sender = expectedCallbackSender;
        expectedCallbackHash = bytes32(0);
        expectedCallbackSender = address(0);

        (address token, uint256 expectedAmount, Call[] memory calls) =
            abi.decode(data, (address, uint256, Call[]));
        if (assets != expectedAmount) revert AmountMismatch();
        _runCalls(calls);
        IERC20(token).forceApprove(sender, assets);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender != expectedCallbackSender) revert UnexpectedSender();
        if (initiator != address(this)) revert UnexpectedInitiator();
        if (keccak256(params) != expectedCallbackHash) revert UnexpectedCallback();

        address sender = expectedCallbackSender;
        expectedCallbackHash = bytes32(0);
        expectedCallbackSender = address(0);

        (address token, uint256 expectedAmount, Call[] memory calls) =
            abi.decode(params, (address, uint256, Call[]));
        if (asset != token) revert AssetMismatch();
        if (amount != expectedAmount) revert AmountMismatch();

        _runCalls(calls);
        IERC20(token).forceApprove(sender, amount + premium);
        return true;
    }

    function _runAaveFlashLoan(
        address pool,
        address token,
        uint256 amount,
        Call[] calldata calls
    ) internal {
        bytes memory params = abi.encode(token, amount, calls);
        expectedCallbackHash = keccak256(params);
        expectedCallbackSender = pool;

        IAaveV3Pool(pool).flashLoanSimple(address(this), token, amount, params, 0);

        if (expectedCallbackHash != bytes32(0)) revert CallbackNotInvoked();
    }

    function _runAaveFlashLoanMode2(
        address pool,
        address debtAsset,
        uint256 amount,
        address onBehalfOf,
        Call[] calldata calls
    ) internal {
        bytes memory params = abi.encode(debtAsset, amount, calls);
        expectedCallbackHash = keccak256(params);
        expectedCallbackSender = pool;

        address[] memory assets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory modes = new uint256[](1);
        assets[0] = debtAsset;
        amounts[0] = amount;
        modes[0] = 2;

        IAaveV3Pool(pool).flashLoan(
            address(this), assets, amounts, modes, onBehalfOf, params, 0
        );

        if (expectedCallbackHash != bytes32(0)) revert CallbackNotInvoked();
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender != expectedCallbackSender) revert UnexpectedSender();
        if (initiator != address(this)) revert UnexpectedInitiator();
        if (keccak256(params) != expectedCallbackHash) revert UnexpectedCallback();

        expectedCallbackHash = bytes32(0);
        expectedCallbackSender = address(0);

        (address debtAsset, uint256 expectedAmount, Call[] memory calls) =
            abi.decode(params, (address, uint256, Call[]));
        if (assets.length != 1 || assets[0] != debtAsset) revert AssetMismatch();
        if (amounts[0] != expectedAmount) revert AmountMismatch();

        _runCalls(calls);
        return true;
    }

    function onMorphoSupplyCollateral(uint256 assets, bytes calldata data) external {
        if (msg.sender != expectedCallbackSender) revert UnexpectedSender();
        if (keccak256(data) != expectedCallbackHash) revert UnexpectedCallback();

        address sender = expectedCallbackSender;
        expectedCallbackHash = bytes32(0);
        expectedCallbackSender = address(0);

        (address collateralToken, uint256 expectedAmount, Call[] memory calls) =
            abi.decode(data, (address, uint256, Call[]));
        if (assets != expectedAmount) revert AmountMismatch();
        _runCalls(calls);
        IERC20(collateralToken).forceApprove(sender, assets);
    }

    function _runCalls(Call[] memory calls) internal {
        uint256 len = calls.length;
        for (uint256 i; i < len; ++i) {
            address to = calls[i].target;
            if (!isTargetAllowlisted[to]) revert TargetNotAllowed(to);

            bytes memory callData = calls[i].data;
            uint256 callValue = calls[i].value;
            bytes memory ret = new bytes(_MAX_RETURN_COPY);
            bool ok;
            assembly {
                ok := call(gas(), to, callValue, add(callData, 0x20), mload(callData), 0, 0)
                let toCopy := returndatasize()
                if gt(toCopy, _MAX_RETURN_COPY) { toCopy := _MAX_RETURN_COPY }
                mstore(ret, toCopy)
                returndatacopy(add(ret, 0x20), 0, toCopy)
            }
            if (!ok) {
                if (calls[i].skipRevert) {
                    emit CallSkipped(i, to, ret);
                } else {
                    assembly {
                        revert(add(ret, 32), mload(ret))
                    }
                }
            }
        }
    }

    receive() external payable {
        if (!_executing && msg.sender != admin) revert UnsolicitedEth();
    }
}