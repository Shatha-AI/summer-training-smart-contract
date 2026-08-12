// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

library ECDSA {
    function recover(bytes32 hash, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid signature length");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "Invalid signature v");
        return ecrecover(hash, v, r, s);
    }

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}

contract SECTokenClaim {

    using ECDSA for bytes32;

    address public owner;
    address public signer;
    address public feeRecipient;
    IERC20  public secToken;

    uint256 public claimFee = 0.001 ether;
    bool    public claimsOpen = false;

    mapping(address => uint256) public totalClaimed;

    event Claimed(address indexed wallet, uint256 amount, uint256 fee);
    event ClaimsToggled(bool open);
    event FeeUpdated(uint256 newFee);
    event SignerUpdated(address newSigner);
    event FeeRecipientUpdated(address newRecipient);
    event TokensWithdrawn(address indexed to, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _secToken, address _feeRecipient, address _signer) {
        require(_secToken     != address(0), "Invalid token");
        require(_feeRecipient != address(0), "Invalid feeRecipient");
        require(_signer       != address(0), "Invalid signer");
        owner        = msg.sender;
        secToken     = IERC20(_secToken);
        feeRecipient = _feeRecipient;
        signer       = _signer;
    }

    function claim(uint256 amount, bytes calldata signature) external payable {
        require(claimsOpen,              "Claims not open");
        require(msg.value == claimFee,   "Incorrect fee");
        require(amount > 0,              "Amount must be > 0");

        bytes32 msgHash = keccak256(abi.encodePacked(msg.sender, amount));
        bytes32 ethHash = msgHash.toEthSignedMessageHash();
        address recovered = ethHash.recover(signature);
        require(recovered == signer, "Invalid signature");

        require(
            secToken.balanceOf(address(this)) >= amount,
            "Insufficient tokens in contract"
        );

        totalClaimed[msg.sender] += amount;

        (bool sent, ) = feeRecipient.call{value: msg.value}("");
        require(sent, "ETH fee transfer failed");

        require(secToken.transfer(msg.sender, amount), "Token transfer failed");

        emit Claimed(msg.sender, amount, msg.value);
    }

    function contractTokenBalance() external view returns (uint256) {
        return secToken.balanceOf(address(this));
    }

    function hasClaim(address wallet) external view returns (uint256) {
        return totalClaimed[wallet];
    }

    function toggleClaims(bool open) external onlyOwner {
        claimsOpen = open;
        emit ClaimsToggled(open);
    }

    function setClaimFee(uint256 newFee) external onlyOwner {
        claimFee = newFee;
        emit FeeUpdated(newFee);
    }

    function setSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "Invalid address");
        signer = newSigner;
        emit SignerUpdated(newSigner);
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid address");
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        require(secToken.transfer(to, amount), "Transfer failed");
        emit TokensWithdrawn(to, amount);
    }

    function withdrawETH(address payable to) external onlyOwner {
        uint256 bal = address(this).balance;
        (bool sent, ) = to.call{value: bal}("");
        require(sent, "ETH withdraw failed");
        emit ETHWithdrawn(to, bal);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}