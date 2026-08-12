pragma solidity 0.8.34;

interface IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4);
}

contract Orb {
    string public constant name = "Sphere Orb";
    string public constant symbol = "ORB";

    address public owner;
    address public minter;
    uint256 public totalSupply;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor() { owner = msg.sender; }

    function assignMinter(address m) external { require(msg.sender == owner, "not owner"); minter = m; }
    function renounce() external { require(msg.sender == owner, "not owner"); owner = address(0); }

    function ownerOf(uint256 id) public view returns (address o) { o = _ownerOf[id]; require(o != address(0), "none"); }
    function balanceOf(address a) public view returns (uint256) { require(a != address(0), "zero"); return _balanceOf[a]; }

    function mint(address to) external returns (uint256 id) {
        require(msg.sender == minter, "not minter");
        require(to != address(0), "zero");
        unchecked { id = ++totalSupply; }
        _ownerOf[id] = to;
        unchecked { _balanceOf[to]++; }
        emit Transfer(address(0), to, id);
    }

    function seedOf(uint256 id) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(address(this), id)));
    }

    function approve(address spender, uint256 id) external {
        address o = _ownerOf[id];
        require(msg.sender == o || isApprovedForAll[o][msg.sender], "auth");
        getApproved[id] = spender;
        emit Approval(o, spender, id);
    }
    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    function transferFrom(address from, address to, uint256 id) public {
        require(from == _ownerOf[id], "from");
        require(to != address(0), "to");
        require(msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id], "auth");
        _ownerOf[id] = to;
        unchecked { _balanceOf[from]--; _balanceOf[to]++; }
        delete getApproved[id];
        emit Transfer(from, to, id);
    }
    function safeTransferFrom(address from, address to, uint256 id) external {
        transferFrom(from, to, id);
        _checkReceiver(from, to, id, "");
    }
    function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) external {
        transferFrom(from, to, id);
        _checkReceiver(from, to, id, data);
    }
    function _checkReceiver(address from, address to, uint256 id, bytes memory data) internal {
        if (to.code.length != 0) {
            require(IERC721Receiver(to).onERC721Received(msg.sender, from, id, data) == IERC721Receiver.onERC721Received.selector, "unsafe");
        }
    }

    function supportsInterface(bytes4 i) external pure returns (bool) {
        return i == 0x01ffc9a7 || i == 0x80ac58cd || i == 0x5b5e139f;
    }

    function tokenURI(uint256 id) external view returns (string memory) {
        require(_ownerOf[id] != address(0), "none");
        uint256 seed = seedOf(id);
        uint256 hue = seed % 360;
        uint256 hue2 = (seed / 7) % 360;
        bytes memory svg = abi.encodePacked(
            "<svg xmlns='http://www.w3.org/2000/svg' width='480' height='480'>",
            "<rect width='480' height='480' fill='#0a0a14'/>",
            "<defs><radialGradient id='g' cx='40%' cy='35%' r='75%'>",
            "<stop offset='0%' stop-color='hsl(", _u2s(hue), ",92%,74%)'/>",
            "<stop offset='55%' stop-color='hsl(", _u2s(hue2), ",82%,46%)'/>",
            "<stop offset='100%' stop-color='#05050a'/></radialGradient></defs>",
            "<circle cx='240' cy='240' r='150' fill='url(#g)'/>",
            "</svg>"
        );
        bytes memory json = abi.encodePacked(
            '{"name":"Sphere Orb #', _u2s(id),
            '","description":"A one of one orb of Sphere.","image":"data:image/svg+xml;base64,', _b64(svg),
            '","attributes":[{"trait_type":"Seed","value":"', _u2s(seed), '"}]}'
        );
        return string(abi.encodePacked("data:application/json;base64,", _b64(json)));
    }

    function _u2s(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 j = v; uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory b = new bytes(len);
        while (v != 0) { len--; b[len] = bytes1(uint8(48 + v % 10)); v /= 10; }
        return string(b);
    }

    function _b64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        string memory result = new string(encodedLen + 32);
        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            for { let i := 0 } lt(i, mload(data)) {} {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)
                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)
                mstore(resultPtr, out)
                resultPtr := add(resultPtr, 4)
            }
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
            mstore(result, encodedLen)
        }
        return result;
    }
}