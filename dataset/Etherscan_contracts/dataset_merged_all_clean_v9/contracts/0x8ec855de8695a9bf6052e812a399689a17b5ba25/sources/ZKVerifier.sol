// SPDX-License-Identifier: MIT
/*
CLOAK — ZK VERIFIER (Groth16 over BN254)

Verifies a succinct proof that a shielded x402 payment is valid and value-
conserving (Merkle membership of the input note, correct nullifier, well-formed
output commitments, bound to the x402 requirement). The verifying key below is a
PLACEHOLDER from a stub setup; replace it with the production trusted setup before
relying on proofs.

Scaffold status: the pairing machinery is real (EVM precompile 0x08); the
verifying key and circuit are not yet wired. Do not advertise proofs as live.
*/
pragma solidity 0.8.24;

library Pairing {
    struct G1Point { uint256 X; uint256 Y; }
    struct G2Point { uint256[2] X; uint256[2] Y; }

    uint256 internal constant PRIME_Q =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    function negate(G1Point memory p) internal pure returns (G1Point memory) {
        if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
        return G1Point(p.X, PRIME_Q - (p.Y % PRIME_Q));
    }

    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint256[4] memory input = [p1.X, p1.Y, p2.X, p2.Y];
        bool ok;
        assembly { ok := staticcall(gas(), 6, input, 0x80, r, 0x40) }
        require(ok, "CLOAK/ec-add");
    }

    function scalar_mul(G1Point memory p, uint256 s) internal view returns (G1Point memory r) {
        uint256[3] memory input = [p.X, p.Y, s];
        bool ok;
        assembly { ok := staticcall(gas(), 7, input, 0x60, r, 0x40) }
        require(ok, "CLOAK/ecmul");
    }

    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length, "CLOAK/pairing-len");
        uint256 elements = p1.length;
        uint256 inputSize = elements * 6;
        uint256[] memory input = new uint256[](inputSize);
        for (uint256 i = 0; i < elements; i++) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint256[1] memory out;
        bool ok;
        assembly {
            ok := staticcall(gas(), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        }
        require(ok, "CLOAK/pairing");
        return out[0] != 0;
    }
}

contract ZKVerifier {

    using Pairing for *;

    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }

    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    /// @dev PLACEHOLDER verifying key. Replace with the trusted-setup export.
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1  = Pairing.G1Point(1, 2);
        vk.beta2  = Pairing.G2Point([uint256(1), 2], [uint256(3), 4]);
        vk.gamma2 = Pairing.G2Point([uint256(1), 2], [uint256(3), 4]);
        vk.delta2 = Pairing.G2Point([uint256(1), 2], [uint256(3), 4]);
        vk.IC = new Pairing.G1Point[](3);
        vk.IC[0] = Pairing.G1Point(1, 2);
        vk.IC[1] = Pairing.G1Point(1, 2);
        vk.IC[2] = Pairing.G1Point(1, 2);
    }

    /// @notice Verify a Groth16 proof against `input` public signals.
    /// @dev Real pairing check; returns false until a real VK + circuit are set.
    function verify(uint256[] memory input, Proof memory proof) public view returns (bool) {
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length, "CLOAK/input-len");

        Pairing.G1Point memory vkX = vk.IC[0];
        for (uint256 i = 0; i < input.length; i++) {
            require(input[i] < Pairing.PRIME_Q, "CLOAK/input-range");
            vkX = Pairing.addition(vkX, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }

        Pairing.G1Point[] memory p1 = new Pairing.G1Point[](4);
        Pairing.G2Point[] memory p2 = new Pairing.G2Point[](4);
        p1[0] = Pairing.negate(proof.A); p2[0] = proof.B;
        p1[1] = vk.alfa1;                p2[1] = vk.beta2;
        p1[2] = vkX;                     p2[2] = vk.gamma2;
        p1[3] = proof.C;                 p2[3] = vk.delta2;
        return Pairing.pairing(p1, p2);
    }

    /// @notice Flattened external entrypoint used by CloakPool.
    function verifyShielded(
        uint256[] calldata input,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c
    ) external view returns (bool) {
        Proof memory p;
        p.A = Pairing.G1Point(a[0], a[1]);
        p.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        p.C = Pairing.G1Point(c[0], c[1]);
        uint256[] memory inp = new uint256[](input.length);
        for (uint256 i = 0; i < input.length; i++) inp[i] = input[i];
        return verify(inp, p);
    }
}