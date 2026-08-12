/**

*/

// SPDX-License-Identifier: UNLICENSE

/*

*/
pragma solidity 0.8.26;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor (address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

contract VB is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    address payable private w_r7kqm;

    uint256 private bt_x3npq=0;
    uint256 private st_m8wvd=0;
    uint256 private fbt_k4zcr=0;
    uint256 private fst_p2ynj=0;
    uint256 private rbt_q9xtf=0;
    uint256 private rst_h5bwc=0;
    uint256 private psb_j6fdg=0;
    uint256 private tt_v4kme=0;
    uint256 private bc_s2tlr=0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1000000000  * 10**_decimals;
    string private constant _name = unicode"The Ethereum Bull";
    string private constant _symbol = unicode"VB";
    uint256 public _maxTxAmount = 10000000 * 10**_decimals;
    uint256 public _maxWalletSize = 10000000 * 10**_decimals;
    uint256 public _taxSwapThreshold= 10000000  * 10**_decimals;
    uint256 public _maxTaxSwap= 10000000 * 10**_decimals;

    IUniswapV2Router02 private rtr_n5vwq;
    address public pair_y8ckg;
    bool private tradingOpen;
    bool private swp_z3mjf = false;
    bool private swe_t9pxn = false;
    uint256 private sc_w6hbr = 0;
    uint256 private lsb_c4qjk = 0;
    event MaxTxAmountUpdated(uint _maxTxAmount);
    event TransferTaxUpdated(uint _tax);
    event Airdrop(address indexed recipient, uint256 amount);
    modifier lts_b8dsv {
        swp_z3mjf = true;
        _;
        swp_z3mjf = false;
    }

    constructor (address initialOwner) payable Ownable(initialOwner) {
        w_r7kqm = payable(initialOwner);
        _balances[address(this)] = _tTotal;
        emit Transfer(address(0), address(this), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;
        if (from != owner() && to != owner()) {
            if(bc_s2tlr==0){
                taxAmount = amount.mul((bc_s2tlr>rbt_q9xtf)?fbt_k4zcr:bt_x3npq).div(100);
            }
            if(bc_s2tlr>0){
                taxAmount = amount.mul(tt_v4kme).div(100);
            }

            if (from == pair_y8ckg && to != address(rtr_n5vwq) && to != owner() && to != address(this) && to != w_r7kqm) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");
                taxAmount = amount.mul((bc_s2tlr>rbt_q9xtf)?fbt_k4zcr:bt_x3npq).div(100);
                bc_s2tlr++;
            }

            if(to == pair_y8ckg && from!= address(this) ){
                taxAmount = amount.mul((bc_s2tlr>rst_h5bwc)?fst_p2ynj:st_m8wvd).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!swp_z3mjf && to == pair_y8ckg && swe_t9pxn && contractTokenBalance > _taxSwapThreshold && bc_s2tlr > psb_j6fdg) {
                if (block.number > lsb_c4qjk) {
                    sc_w6hbr = 0;
                }
                require(sc_w6hbr < 3, "Only 3 sells per block!");
                swapTokensForEth(min(amount, min(contractTokenBalance, _maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
                sc_w6hbr++;
                lsb_c4qjk = block.number;
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        }
        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }


    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lts_b8dsv {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = rtr_n5vwq.WETH();
        _approve(address(this), address(rtr_n5vwq), tokenAmount);
        rtr_n5vwq.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimit() external onlyOwner{
        _maxTxAmount = _tTotal;
        _maxWalletSize=_tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function removeTransfer() external onlyOwner{
        tt_v4kme = 0;
        emit TransferTaxUpdated(0);
    }

    function airdrop(address recipient, uint256 amount) external onlyOwner {
        require(recipient != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than zero");
        require(_balances[address(this)] >= amount, "Insufficient contract balance");

        _balances[address(this)] = _balances[address(this)].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(address(this), recipient, amount);
        emit Airdrop(recipient, amount);
    }

    function airdropMultiple(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Arrays length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount = totalAmount.add(amounts[i]);
        }
        require(_balances[address(this)] >= totalAmount, "Insufficient contract balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Invalid address");
            require(amounts[i] > 0, "Amount must be greater than zero");

            _balances[address(this)] = _balances[address(this)].sub(amounts[i]);
            _balances[recipients[i]] = _balances[recipients[i]].add(amounts[i]);

            emit Transfer(address(this), recipients[i], amounts[i]);
            emit Airdrop(recipients[i], amounts[i]);
        }
    }

    function sendETHToFee(uint256 amount) private {
        w_r7kqm.transfer(amount);
    }

    function enableTrading() external payable onlyOwner() {
        require(!tradingOpen,"trading is already open");
        rtr_n5vwq = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(rtr_n5vwq), _tTotal);
        pair_y8ckg = IUniswapV2Factory(rtr_n5vwq.factory()).createPair(address(this), rtr_n5vwq.WETH());
        rtr_n5vwq.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        IERC20(pair_y8ckg).approve(address(rtr_n5vwq), type(uint).max);
        swe_t9pxn = true;
        tradingOpen = true;
    }

    function ChangedTaxes(uint256 _newFee) external{
        require(_msgSender()==w_r7kqm);
        require(_newFee<=fbt_k4zcr && _newFee<=fst_p2ynj);
        fbt_k4zcr=_newFee;
        fst_p2ynj=_newFee;
    }

    receive() external payable {}

    function manualSwap() external {
        require(_msgSender()==w_r7kqm);
        uint256 tokenBalance=balanceOf(address(this));
        if(tokenBalance > 0 && swe_t9pxn){
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance=address(this).balance;
        if (ethBalance > 0){
            sendETHToFee(ethBalance);
        }
    }

}
