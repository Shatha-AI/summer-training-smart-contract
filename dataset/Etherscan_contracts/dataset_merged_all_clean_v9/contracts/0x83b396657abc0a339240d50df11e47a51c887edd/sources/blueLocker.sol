// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
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

    function renounceOwnership() external virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);
}

interface IERC721Enumerable is IERC721 {
    function totalSupply() external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

library Structs {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
}

interface IUniswapPositions is IERC721Enumerable {
    function collect(Structs.CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96,
            address,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256,
            uint256,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

contract blueLocker is Ownable, IERC721Receiver {

    IUniswapPositions public immutable positionsContract;

    event RequestedLPWithdraw(uint256 tokenId);
    event WithdrewLP(uint256 tokenId);
    event CanceledLpWithdrawRequest();
    event HarvestedFees(uint256 amount0, uint256 amount1);

    uint256 public lpWithdrawRequestTimestamp;
    uint256 public lpWithdrawRequestDuration = 69420000 days;
    bool public lpWithdrawRequestPending;
    uint256 public lpTokenIdToWithdraw;

    receive() payable external{}

    constructor() {
        positionsContract = IUniswapPositions(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    }

    // 
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function getOpenPositions() public view returns (uint256[] memory){
        uint256[] memory tokenIds = new uint256[](positionsContract.balanceOf(address(this)));
        for(uint256 i = 0; i < tokenIds.length; i++){
            tokenIds[i] = positionsContract.tokenOfOwnerByIndex(address(this), i);
        }
        return tokenIds;
    }

    function collectFromAllPositions() external onlyOwner{
        uint256[] memory openPositions = getOpenPositions();
        for(uint256 i = 0; i < openPositions.length; i++){
            (uint256 amount0, uint256 amount1) = positionsContract.collect(Structs.CollectParams({
                tokenId: openPositions[i],
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            }));
            emit HarvestedFees(amount0,amount1);
        }
    }

    function collectFromSinglePosition(uint256 _tokenId) external onlyOwner{
        (uint256 amount0, uint256 amount1) = positionsContract.collect(Structs.CollectParams({
            tokenId: _tokenId,
            recipient: msg.sender,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        }));
        emit HarvestedFees(amount0,amount1);
    }

    function sendEth() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "withdraw unsuccessful");
    }

    function transferForeignToken(address _token, address _to) external onlyOwner {
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(_token),_to, _contractBalance);
    }

    function getPositionInfo(uint256 _tokenId) public view returns (
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1){
                (,
                ,
                token0,
                token1,
                fee,
                tickLower,
                tickUpper,
                liquidity,
                ,
                ,
                tokensOwed0,
                tokensOwed1) = positionsContract.positions(_tokenId);
            }

    function requestToWithdrawLP(uint256 _tokenId) external onlyOwner {
        require(!lpWithdrawRequestPending, "Already pending");
        lpWithdrawRequestTimestamp = block.timestamp;
        lpWithdrawRequestPending = true;
        lpTokenIdToWithdraw = _tokenId;
        emit RequestedLPWithdraw(lpTokenIdToWithdraw);
    }

    function nextAvailableLpWithdrawDate() public view returns (uint256){
        if(lpWithdrawRequestPending){
            return lpWithdrawRequestTimestamp + lpWithdrawRequestDuration;
        } else {
            return 0;
        }
    }

    function withdrawRequestedLP(address _to) external onlyOwner {
        require(block.timestamp >= nextAvailableLpWithdrawDate() && nextAvailableLpWithdrawDate() > 0, "Must wait");
        positionsContract.transferFrom(address(this), _to, lpTokenIdToWithdraw);
        emit WithdrewLP(lpTokenIdToWithdraw);
    }

    function cancelLPWithdrawRequest() external onlyOwner {
        lpWithdrawRequestPending = false;
        lpWithdrawRequestTimestamp = 0;
        lpTokenIdToWithdraw = 0;
        emit CanceledLpWithdrawRequest();
    }
}