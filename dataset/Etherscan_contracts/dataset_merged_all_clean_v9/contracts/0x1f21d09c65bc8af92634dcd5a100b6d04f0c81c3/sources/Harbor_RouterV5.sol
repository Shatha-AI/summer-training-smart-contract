// SPDX-License-Identifier: MIT
// -------------------
// Router Version: 5.0
// -------------------
pragma solidity 0.8.34;

// ERC20 Interface
interface iERC20 {
    function balanceOf(address) external view returns (uint256);
}

// ROUTER Interface
interface iROUTER {
    function depositWithExpiry(address, address, uint, string calldata, uint) external;
}

// Executor Interface
interface iExecutor {
    function execute(address asset, uint256 amount, address target, bytes calldata payload) external payable returns (bytes memory);
}

// Harbor_RouterV5 is managed by XNode Vaults
contract Harbor_RouterV5 {

    struct Coin {
        address asset;
        uint amount;
    }

    // Vault allowance for each asset
    mapping(address => mapping(address => uint)) private _vaultAllowance;

    bytes4 private constant APPROVE_SIG = 0x095ea7b3;        // approve(address,uint256)
    bytes4 private constant TRANSFER_SIG = 0xa9059cbb;      // transfer(address,uint256)
    bytes4 private constant TRANSFER_FROM_SIG = 0x23b872dd;  // transferFrom(address,address,uint256)

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // Immutable executor address
    iExecutor public immutable executor;

    // Emitted for all deposits, the memo distinguishes for swap, add, remove, donate etc
    event Deposit(address indexed to, address indexed asset, uint amount, string memo);

    // Emitted for all outgoing transfers, the vault dictates who sent it, memo used to track.
    event TransferOut(address indexed vault, address indexed to, address asset, uint amount, string memo);

    // Changes the spend allowance between vaults
    event TransferAllowance(address indexed oldVault, address indexed newVault, address asset, uint amount, string memo);

    // Emitted for all outgoing transferAndCalls via the executor.
    event TransferOutAndCall(address indexed vault, address asset, uint256 assetAmount, address target, uint256 callValue, bytes callData, address refundAddress);

    // Specifically used to batch send the entire vault assets
    event VaultTransfer(address indexed oldVault, address indexed newVault, Coin[] coins, string memo);

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    constructor(address _executor) {
        require(_executor != address(0), "Harbor_Router: zero executor");
        _status = _NOT_ENTERED;
        executor = iExecutor(_executor);
    }

    // Deposit with Expiry (preferred)
    function depositWithExpiry(address payable vault, address asset, uint amount, string memory memo, uint expiration) external payable {
        require(block.timestamp < expiration, "Harbor_Router: expired");
        deposit(vault, asset, amount, memo);
    }

    // Deposit an asset with a memo. ETH is forwarded, ERC-20 stays in ROUTER
    function deposit(address payable vault, address asset, uint amount, string memory memo) private nonReentrant{
        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            bool success = vault.send(safeAmount);
            require(success);
        } else {
            require(msg.value == 0, "unexpected eth");  // protect user from accidentally locking up eth
            safeAmount = safeTransferFrom(asset, amount); // Transfer asset
            _vaultAllowance[vault][asset] += safeAmount; // Credit to chosen vault
        }
        emit Deposit(vault, asset, safeAmount, memo);
    }

    //############################## ALLOWANCE TRANSFERS ##############################

    // Use for churning to new vaults
    function transferAllowance(address router, address newVault, address asset, uint amount, string memory memo) external nonReentrant {
        if (router == address(this)){
            _adjustAllowances(newVault, asset, amount);
            emit TransferAllowance(msg.sender, newVault, asset, amount, memo);
        } else {
            _routerDeposit(router, newVault, asset, amount, memo);
        }
    }

    //############################## ASSET TRANSFERS ##############################

    // Any vault calls to transfer any asset to any recipient.
    // Note: Contract recipients of ETH are only given 2300 Gas to complete execution.
    function transferOut(address payable to, address asset, uint amount, string memory memo) public payable nonReentrant {
        uint safeAmount;
        if(asset == address(0)){
            safeAmount = msg.value;
            bool success = to.send(safeAmount); // Send ETH.
            if (!success) {
                payable(address(msg.sender)).transfer(safeAmount);
            }
        } else {
            _vaultAllowance[msg.sender][asset] -= amount; // Reduce allowance
            (bool success, bytes memory data) = asset.call(abi.encodeWithSelector(TRANSFER_SIG, to, amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))));
            safeAmount = amount;
        }
        emit TransferOut(msg.sender, to, asset, safeAmount, memo);
    }

    // Vault calls to execute an arbitrary call on a target via the executor contract.
    // For ERC20: debits vault allowance, approves executor, executor pulls tokens and calls target.
    //   msg.value carries optional extra native value (call_value) forwarded alongside the token.
    // For ETH (asset=0x0): msg.value IS the coin amount. The amount param is passed through
    //   to the event for observability but the contract uses msg.value for the actual transfer.
    // The executor is a separate contract so msg.sender inside the target is the executor,
    // not the router — preventing the target from exercising user approvals on the router.
    function transferOutAndCall(
        address payable target,
        address asset,
        uint amount,
        bytes memory callData,
        address payable refundAddress
    ) public payable nonReentrant {
        uint256 _callValue = msg.value;

        // If an ERC20 asset is specified, debit vault allowance and approve executor
        if (asset != address(0) && amount > 0) {
            _vaultAllowance[msg.sender][asset] -= amount;
            _safeApprove(asset, address(executor), amount);
        }

        // Delegate the call to the executor contract
        (bool success, ) = address(executor).call{value: _callValue}(
            abi.encodeWithSelector(iExecutor.execute.selector, asset, amount, target, callData)
        );

        if (!success) {
            require(refundAddress != address(0), "Harbor_Router: zero refund address");
            if (_callValue > 0) {
                bool ethSuccess = refundAddress.send(_callValue);
                require(ethSuccess, "Harbor_Router: ETH refund failed");
            }
            if (asset != address(0) && amount > 0) {
                (bool transferSuccess, bytes memory transferData) = asset.call(abi.encodeWithSelector(TRANSFER_SIG, refundAddress, amount));
                require(transferSuccess && (transferData.length == 0 || abi.decode(transferData, (bool))));
            }
        }

        // Revoke any leftover ERC20 approval to executor
        if (asset != address(0) && amount > 0) {
            _safeApprove(asset, address(executor), 0);
        }

        // For ETH, emit msg.value as the amount so observers see the real coin amount.
        uint256 emitAmount = (asset == address(0)) ? msg.value : amount;
        emit TransferOutAndCall(msg.sender, asset, emitAmount, target, _callValue, callData, refundAddress);
    }

    //############################## VAULT MANAGEMENT ##############################

    // A vault can call to return all assets to a vault, including ETH.
    function returnVaultAssets(address router, address payable vault, Coin[] memory coins, string memory memo) external payable nonReentrant {
        if (router == address(this)){
            for(uint i = 0; i < coins.length; i++){
                _adjustAllowances(vault, coins[i].asset, coins[i].amount);
            }
            emit VaultTransfer(msg.sender, vault, coins, memo); // Does not include ETH.
        } else {
            for(uint i = 0; i < coins.length; i++){
                _routerDeposit(router, vault, coins[i].asset, coins[i].amount, memo);
            }
        }
        bool success = vault.send(msg.value);
        require(success);
    }

    //############################## HELPERS ##############################

    function vaultAllowance(address vault, address token) public view returns(uint amount){
        return _vaultAllowance[vault][token];
    }

    // Safe transferFrom in case asset charges transfer fees
    function safeTransferFrom(address _asset, uint _amount) internal returns(uint amount) {
        uint _startBal = iERC20(_asset).balanceOf(address(this));
        (bool success, bytes memory data) = _asset.call(abi.encodeWithSelector(TRANSFER_FROM_SIG, msg.sender, address(this), _amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
        return (iERC20(_asset).balanceOf(address(this)) - _startBal);
    }

    // Decrements and Increments Allowances between two vaults
    function _adjustAllowances(address _newVault, address _asset, uint _amount) internal {
        _vaultAllowance[msg.sender][_asset] -= _amount;
        _vaultAllowance[_newVault][_asset] += _amount;
    }

    // Adjust allowance and forwards funds to new router, credits allowance to desired vault
    function _routerDeposit(address _router, address _vault, address _asset, uint _amount, string memory _memo) internal {
        _vaultAllowance[msg.sender][_asset] -= _amount;
        _safeApprove(_asset, _router, _amount);
        iROUTER(_router).depositWithExpiry(_vault, _asset, _amount, _memo, type(uint).max); // Transfer by depositing
    }

    // Safe approve for ERC20 tokens (handles non-standard tokens that return no data)
    function _safeApprove(address _asset, address _spender, uint _amount) internal {
        (bool success, bytes memory data) = _asset.call(abi.encodeWithSelector(APPROVE_SIG, _spender, _amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Harbor_Router: approve failed");
    }
}