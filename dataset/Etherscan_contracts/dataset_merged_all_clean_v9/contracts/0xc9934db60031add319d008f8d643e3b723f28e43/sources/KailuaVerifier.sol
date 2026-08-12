// SPDX-License-Identifier: Apache-2.0
pragma solidity =0.8.24 ^0.8.0 ^0.8.15 ^0.8.9;

// lib/optimism/packages/contracts-bedrock/interfaces/universal/ISemver.sol

/// @title ISemver
/// @notice ISemver is a simple contract for ensuring that contracts are
///         versioned using semantic versioning.
interface ISemver {
    /// @notice Getter for the semantic version of the contract. This is not
    ///         meant to be used onchain but instead meant to be used by offchain
    ///         tooling.
    /// @return Semver contract version as a string.
    function version() external view returns (string memory);
}

// lib/optimism/packages/contracts-bedrock/src/dispute/lib/LibPosition.sol

using LibPosition for Position global;

/// @notice A `Position` represents a position of a claim within the game tree.
/// @dev This is represented as a "generalized index" where the high-order bit
/// is the level in the tree and the remaining bits is a unique bit pattern, allowing
/// a unique identifier for each node in the tree. Mathematically, it is calculated
/// as 2^{depth} + indexAtDepth.
type Position is uint128;

/// @title LibPosition
/// @notice This library contains helper functions for working with the `Position` type.
library LibPosition {
    /// @notice the `MAX_POSITION_BITLEN` is the number of bits that the `Position` type, and the implementation of
    ///         its behavior within this library, can safely support.
    uint8 internal constant MAX_POSITION_BITLEN = 126;

    /// @notice Computes a generalized index (2^{depth} + indexAtDepth).
    /// @param _depth The depth of the position.
    /// @param _indexAtDepth The index at the depth of the position.
    /// @return position_ The computed generalized index.
    function wrap(uint8 _depth, uint128 _indexAtDepth) internal pure returns (Position position_) {
        assembly {
            // gindex = 2^{_depth} + _indexAtDepth
            position_ := add(shl(_depth, 1), _indexAtDepth)
        }
    }

    /// @notice Pulls the `depth` out of a `Position` type.
    /// @param _position The generalized index to get the `depth` of.
    /// @return depth_ The `depth` of the `position` gindex.
    /// @custom:attribution Solady <https://github.com/Vectorized/Solady>
    function depth(Position _position) internal pure returns (uint8 depth_) {
        // Return the most significant bit offset, which signifies the depth of the gindex.
        assembly {
            depth_ := or(depth_, shl(6, lt(0xffffffffffffffff, shr(depth_, _position))))
            depth_ := or(depth_, shl(5, lt(0xffffffff, shr(depth_, _position))))

            // For the remaining 32 bits, use a De Bruijn lookup.
            _position := shr(depth_, _position)
            _position := or(_position, shr(1, _position))
            _position := or(_position, shr(2, _position))
            _position := or(_position, shr(4, _position))
            _position := or(_position, shr(8, _position))
            _position := or(_position, shr(16, _position))

            depth_ :=
                or(
                    depth_,
                    byte(
                        shr(251, mul(_position, shl(224, 0x07c4acdd))),
                        0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f
                    )
                )
        }
    }

    /// @notice Pulls the `indexAtDepth` out of a `Position` type.
    ///         The `indexAtDepth` is the left/right index of a position at a specific depth within
    ///         the binary tree, starting from index 0. For example, at gindex 2, the `depth` = 1
    ///         and the `indexAtDepth` = 0.
    /// @param _position The generalized index to get the `indexAtDepth` of.
    /// @return indexAtDepth_ The `indexAtDepth` of the `position` gindex.
    function indexAtDepth(Position _position) internal pure returns (uint128 indexAtDepth_) {
        // Return bits p_{msb-1}...p_{0}. This effectively pulls the 2^{depth} out of the gindex,
        // leaving only the `indexAtDepth`.
        uint256 msb = depth(_position);
        assembly {
            indexAtDepth_ := sub(_position, shl(msb, 1))
        }
    }

    /// @notice Get the left child of `_position`.
    /// @param _position The position to get the left position of.
    /// @return left_ The position to the left of `position`.
    function left(Position _position) internal pure returns (Position left_) {
        assembly {
            left_ := shl(1, _position)
        }
    }

    /// @notice Get the right child of `_position`
    /// @param _position The position to get the right position of.
    /// @return right_ The position to the right of `position`.
    function right(Position _position) internal pure returns (Position right_) {
        assembly {
            right_ := or(1, shl(1, _position))
        }
    }

    /// @notice Get the parent position of `_position`.
    /// @param _position The position to get the parent position of.
    /// @return parent_ The parent position of `position`.
    function parent(Position _position) internal pure returns (Position parent_) {
        assembly {
            parent_ := shr(1, _position)
        }
    }

    /// @notice Get the deepest, right most gindex relative to the `position`. This is equivalent to
    ///         calling `right` on a position until the maximum depth is reached.
    /// @param _position The position to get the relative deepest, right most gindex of.
    /// @param _maxDepth The maximum depth of the game.
    /// @return rightIndex_ The deepest, right most gindex relative to the `position`.
    function rightIndex(Position _position, uint256 _maxDepth) internal pure returns (Position rightIndex_) {
        uint256 msb = depth(_position);
        assembly {
            let remaining := sub(_maxDepth, msb)
            rightIndex_ := or(shl(remaining, _position), sub(shl(remaining, 1), 1))
        }
    }

    /// @notice Get the deepest, right most trace index relative to the `position`. This is
    ///         equivalent to calling `right` on a position until the maximum depth is reached and
    ///         then finding its index at depth.
    /// @param _position The position to get the relative trace index of.
    /// @param _maxDepth The maximum depth of the game.
    /// @return traceIndex_ The trace index relative to the `position`.
    function traceIndex(Position _position, uint256 _maxDepth) internal pure returns (uint256 traceIndex_) {
        uint256 msb = depth(_position);
        assembly {
            let remaining := sub(_maxDepth, msb)
            traceIndex_ := sub(or(shl(remaining, _position), sub(shl(remaining, 1), 1)), shl(_maxDepth, 1))
        }
    }

    /// @notice Gets the position of the highest ancestor of `_position` that commits to the same
    ///         trace index.
    /// @param _position The position to get the highest ancestor of.
    /// @return ancestor_ The highest ancestor of `position` that commits to the same trace index.
    function traceAncestor(Position _position) internal pure returns (Position ancestor_) {
        // Create a field with only the lowest unset bit of `_position` set.
        Position lsb;
        assembly {
            lsb := and(not(_position), add(_position, 1))
        }
        // Find the index of the lowest unset bit within the field.
        uint256 msb = depth(lsb);
        // The highest ancestor that commits to the same trace index is the original position
        // shifted right by the index of the lowest unset bit.
        assembly {
            let a := shr(msb, _position)
            // Bound the ancestor to the minimum gindex, 1.
            ancestor_ := or(a, iszero(a))
        }
    }

    /// @notice Gets the position of the highest ancestor of `_position` that commits to the same
    ///         trace index, while still being below `_upperBoundExclusive`.
    /// @param _position The position to get the highest ancestor of.
    /// @param _upperBoundExclusive The exclusive upper depth bound, used to inform where to stop in order
    ///                             to not escape a sub-tree.
    /// @return ancestor_ The highest ancestor of `position` that commits to the same trace index.
    function traceAncestorBounded(
        Position _position,
        uint256 _upperBoundExclusive
    )
        internal
        pure
        returns (Position ancestor_)
    {
        // This function only works for positions that are below the upper bound.
        if (_position.depth() <= _upperBoundExclusive) {
            assembly {
                // Revert with `ClaimAboveSplit()`
                mstore(0x00, 0xb34b5c22)
                revert(0x1C, 0x04)
            }
        }

        // Grab the global trace ancestor.
        ancestor_ = traceAncestor(_position);

        // If the ancestor is above or at the upper bound, shift it to be below the upper bound.
        // This should be a special case that only covers positions that commit to the final leaf
        // in a sub-tree.
        if (ancestor_.depth() <= _upperBoundExclusive) {
            ancestor_ = ancestor_.rightIndex(_upperBoundExclusive + 1);
        }
    }

    /// @notice Get the move position of `_position`, which is the left child of:
    ///         1. `_position` if `_isAttack` is true.
    ///         2. `_position | 1` if `_isAttack` is false.
    /// @param _position The position to get the relative attack/defense position of.
    /// @param _isAttack Whether or not the move is an attack move.
    /// @return move_ The move position relative to `position`.
    function move(Position _position, bool _isAttack) internal pure returns (Position move_) {
        assembly {
            move_ := shl(1, or(iszero(_isAttack), _position))
        }
    }

    /// @notice Get the value of a `Position` type in the form of the underlying uint128.
    /// @param _position The position to get the value of.
    /// @return raw_ The value of the `position` as a uint128 type.
    function raw(Position _position) internal pure returns (uint128 raw_) {
        assembly {
            raw_ := _position
        }
    }
}

// lib/risc0-ethereum/contracts/src/Util.sol
// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// @notice reverse the byte order of the uint256 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint256(uint256 input) pure returns (uint256 v) {
    v = input;

    // swap bytes
    v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
        | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);

    // swap 2-byte long pairs
    v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
        | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);

    // swap 4-byte long pairs
    v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
        | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);

    // swap 8-byte long pairs
    v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
        | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);

    // swap 16-byte long pairs
    v = (v >> 128) | (v << 128);
}

/// @notice reverse the byte order of the uint32 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint32(uint32 input) pure returns (uint32 v) {
    v = input;

    // swap bytes
    v = ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);

    // swap 2-byte long pairs
    v = (v >> 16) | (v << 16);
}

/// @notice reverse the byte order of the uint16 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint16(uint16 input) pure returns (uint16 v) {
    v = input;

    // swap bytes
    v = (v >> 8) | ((v & 0x00FF) << 8);
}

// lib/risc0-ethereum/contracts/src/IRiscZeroVerifier.sol
// Copyright 2025 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// @notice A receipt attesting to a claim using the RISC Zero proof system.
/// @dev A receipt contains two parts: a seal and a claim.
///
/// The seal is a zero-knowledge proof attesting to knowledge of a witness for the claim. The claim
/// is a set of public outputs, and for zkVM execution is the hash of a `ReceiptClaim` struct.
///
/// IMPORTANT: The `claimDigest` field must be a hash computed by the caller for verification to
/// have meaningful guarantees. Treat this similar to verifying an ECDSA signature, in that hashing
/// is a key operation in verification. The most common way to calculate this hash is to use the
/// `ReceiptClaimLib.ok(imageId, journalDigest).digest()` for successful executions.
struct Receipt {
    bytes seal;
    bytes32 claimDigest;
}

/// @notice Public claims about a zkVM guest execution, such as the journal committed to by the guest.
/// @dev Also includes important information such as the exit code and the starting and ending system
/// state (i.e. the state of memory). `ReceiptClaim` is a "Merkle-ized struct" supporting
/// partial openings of the underlying fields from a hash commitment to the full structure.
struct ReceiptClaim {
    /// @notice Digest of the SystemState just before execution has begun.
    bytes32 preStateDigest;
    /// @notice Digest of the SystemState just after execution has completed.
    bytes32 postStateDigest;
    /// @notice The exit code for the execution.
    ExitCode exitCode;
    /// @notice A digest of the input to the guest.
    /// @dev This field is currently unused and must be set to the zero digest.
    bytes32 input;
    /// @notice Digest of the Output of the guest, including the journal
    /// and assumptions set during execution.
    bytes32 output;
}

library ReceiptClaimLib {
    using OutputLib for Output;
    using SystemStateLib for SystemState;

    bytes32 constant TAG_DIGEST = sha256("risc0.ReceiptClaim");

    // Define a constant to ensure hashing is done at compile time. Can't use the
    // SystemStateLib.digest method here because the Solidity compiler complains.
    bytes32 constant SYSTEM_STATE_ZERO_DIGEST = 0xa3acc27117418996340b84e5a90f3ef4c49d22c79e44aad822ec9c313e1eb8e2;

    /// @notice Construct a ReceiptClaim from the given imageId and journalDigest.
    ///         Returned ReceiptClaim will represent a successful execution of the zkVM, running
    ///         the program committed by imageId and resulting in the journal specified by
    ///         journalDigest.
    /// @param imageId The identifier for the guest program.
    /// @param journalDigest The SHA-256 digest of the journal bytes.
    /// @dev Input hash and postStateDigest are set to all-zeros (i.e. no committed input, or
    ///      final memory state), the exit code is (Halted, 0), and there are no assumptions
    ///      (i.e. the receipt is unconditional).
    function ok(bytes32 imageId, bytes32 journalDigest) internal pure returns (ReceiptClaim memory) {
        return ReceiptClaim(
            imageId,
            SYSTEM_STATE_ZERO_DIGEST,
            ExitCode(SystemExitCode.Halted, 0),
            bytes32(0),
            Output(journalDigest, bytes32(0)).digest()
        );
    }

    function digest(ReceiptClaim memory claim) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                claim.input,
                claim.preStateDigest,
                claim.postStateDigest,
                claim.output,
                // data
                uint32(claim.exitCode.system) << 24,
                uint32(claim.exitCode.user) << 24,
                // down.length
                uint16(4) << 8
            )
        );
    }
}

/// @notice Commitment to the memory state and program counter (pc) of the zkVM.
/// @dev The "pre" and "post" fields of the ReceiptClaim are digests of the system state at the
///      start are stop of execution. Programs are loaded into the zkVM by creating a memory image
///      of the loaded program, and creating a system state for initializing the zkVM. This is
///      known as the "image ID".
struct SystemState {
    /// @notice Program counter.
    uint32 pc;
    /// @notice Root hash of a merkle tree which confirms the integrity of the memory image.
    bytes32 merkle_root;
}

library SystemStateLib {
    bytes32 constant TAG_DIGEST = sha256("risc0.SystemState");

    function digest(SystemState memory state) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                state.merkle_root,
                // data
                reverseByteOrderUint32(state.pc),
                // down.length
                uint16(1) << 8
            )
        );
    }
}

/// @notice Exit condition indicated by the zkVM at the end of the guest execution.
/// @dev Exit codes have a "system" part and a "user" part. Semantically, the system part is set to
/// indicate the type of exit (e.g. halt, pause, or system split) and is directly controlled by the
/// zkVM. The user part is an exit code, similar to exit codes used in Linux, chosen by the guest
/// program to indicate additional information (e.g. 0 to indicate success or 1 to indicate an
/// error).
struct ExitCode {
    SystemExitCode system;
    uint8 user;
}

/// @notice Exit condition indicated by the zkVM at the end of the execution covered by this proof.
/// @dev
/// `Halted` indicates normal termination of a program with an interior exit code returned from the
/// guest program. A halted program cannot be resumed.
///
/// `Paused` indicates the execution ended in a paused state with an interior exit code set by the
/// guest program. A paused program can be resumed such that execution picks up where it left
/// of, with the same memory state.
///
/// `SystemSplit` indicates the execution ended on a host-initiated system split. System split is
/// mechanism by which the host can temporarily stop execution of the execution ended in a system
/// split has no output and no conclusions can be drawn about whether the program will eventually
/// halt. System split is used in continuations to split execution into individually provable segments.
enum SystemExitCode {
    Halted,
    Paused,
    SystemSplit
}

/// @notice Output field in the `ReceiptClaim`, committing to a claimed journal and assumptions list.
struct Output {
    /// @notice Digest of the journal committed to by the guest execution.
    bytes32 journalDigest;
    /// @notice Digest of the ordered list of `ReceiptClaim` digests corresponding to the
    /// calls to `env::verify` and `env::verify_integrity`.
    /// @dev Verifying the integrity of a `Receipt` corresponding to a `ReceiptClaim` with a
    /// non-empty assumptions list does not guarantee unconditionally any of the claims over the
    /// guest execution (i.e. if the assumptions list is non-empty, then the journal digest cannot
    /// be trusted to correspond to a genuine execution). The claims can be checked by additional
    /// verifying a `Receipt` for every digest in the assumptions list.
    bytes32 assumptionsDigest;
}

library OutputLib {
    bytes32 constant TAG_DIGEST = sha256("risc0.Output");

    function digest(Output memory output) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                output.journalDigest,
                output.assumptionsDigest,
                // down.length
                uint16(2) << 8
            )
        );
    }
}

/// @notice Error raised when cryptographic verification of the zero-knowledge proof fails.
error VerificationFailed();

/// @notice Verifier interface for RISC Zero receipts of execution.
interface IRiscZeroVerifier {
    /// @notice Verify that the given seal is a valid RISC Zero proof of execution with the
    ///     given image ID and journal digest. Reverts on failure.
    /// @dev This method additionally ensures that the input hash is all-zeros (i.e. no
    /// committed input), the exit code is (Halted, 0), and there are no assumptions (i.e. the
    /// receipt is unconditional).
    /// @param seal The encoded cryptographic proof (i.e. SNARK).
    /// @param imageId The identifier for the guest program.
    /// @param journalDigest The SHA-256 digest of the journal bytes.
    function verify(bytes calldata seal, bytes32 imageId, bytes32 journalDigest) external view;

    /// @notice Verify that the given receipt is a valid RISC Zero receipt, ensuring the `seal` is
    /// valid a cryptographic proof of the execution with the given `claim`. Reverts on failure.
    /// @param receipt The receipt to be verified.
    function verifyIntegrity(Receipt calldata receipt) external view;
}

// lib/optimism/packages/contracts-bedrock/src/dispute/lib/LibUDT.sol

// Libraries

using LibClaim for Claim global;
using LibHash for Hash global;
using LibDuration for Duration global;
using LibClock for Clock global;
using LibGameId for GameId global;
using LibTimestamp for Timestamp global;
using LibVMStatus for VMStatus global;
using LibGameType for GameType global;

/// @notice A `Clock` represents a packed `Duration` and `Timestamp`
/// @dev The packed layout of this type is as follows:
/// ┌────────────┬────────────────┐
/// │    Bits    │     Value      │
/// ├────────────┼────────────────┤
/// │ [0, 64)    │ Duration       │
/// │ [64, 128)  │ Timestamp      │
/// └────────────┴────────────────┘
type Clock is uint128;

/// @title LibClock
/// @notice This library contains helper functions for working with the `Clock` type.
library LibClock {
    /// @notice Packs a `Duration` and `Timestamp` into a `Clock` type.
    /// @param _duration The `Duration` to pack into the `Clock` type.
    /// @param _timestamp The `Timestamp` to pack into the `Clock` type.
    /// @return clock_ The `Clock` containing the `_duration` and `_timestamp`.
    function wrap(Duration _duration, Timestamp _timestamp) internal pure returns (Clock clock_) {
        assembly {
            clock_ := or(shl(0x40, _duration), _timestamp)
        }
    }

    /// @notice Pull the `Duration` out of a `Clock` type.
    /// @param _clock The `Clock` type to pull the `Duration` out of.
    /// @return duration_ The `Duration` pulled out of `_clock`.
    function duration(Clock _clock) internal pure returns (Duration duration_) {
        // Shift the high-order 64 bits into the low-order 64 bits, leaving only the `duration`.
        assembly {
            duration_ := shr(0x40, _clock)
        }
    }

    /// @notice Pull the `Timestamp` out of a `Clock` type.
    /// @param _clock The `Clock` type to pull the `Timestamp` out of.
    /// @return timestamp_ The `Timestamp` pulled out of `_clock`.
    function timestamp(Clock _clock) internal pure returns (Timestamp timestamp_) {
        // Clean the high-order 192 bits by shifting the clock left and then right again, leaving
        // only the `timestamp`.
        assembly {
            timestamp_ := shr(0xC0, shl(0xC0, _clock))
        }
    }

    /// @notice Get the value of a `Clock` type in the form of the underlying uint128.
    /// @param _clock The `Clock` type to get the value of.
    /// @return clock_ The value of the `Clock` type as a uint128 type.
    function raw(Clock _clock) internal pure returns (uint128 clock_) {
        assembly {
            clock_ := _clock
        }
    }
}

/// @notice A `GameId` represents a packed 4 byte game ID, a 8 byte timestamp, and a 20 byte address.
/// @dev The packed layout of this type is as follows:
/// ┌───────────┬───────────┐
/// │   Bits    │   Value   │
/// ├───────────┼───────────┤
/// │ [0, 32)   │ Game Type │
/// │ [32, 96)  │ Timestamp │
/// │ [96, 256) │ Address   │
/// └───────────┴───────────┘
type GameId is bytes32;

/// @title LibGameId
/// @notice Utility functions for packing and unpacking GameIds.
library LibGameId {
    /// @notice Packs values into a 32 byte GameId type.
    /// @param _gameType The game type.
    /// @param _timestamp The timestamp of the game's creation.
    /// @param _gameProxy The game proxy address.
    /// @return gameId_ The packed GameId.
    function pack(
        GameType _gameType,
        Timestamp _timestamp,
        address _gameProxy
    )
        internal
        pure
        returns (GameId gameId_)
    {
        assembly {
            gameId_ := or(or(shl(224, _gameType), shl(160, _timestamp)), _gameProxy)
        }
    }

    /// @notice Unpacks values from a 32 byte GameId type.
    /// @param _gameId The packed GameId.
    /// @return gameType_ The game type.
    /// @return timestamp_ The timestamp of the game's creation.
    /// @return gameProxy_ The game proxy address.
    function unpack(GameId _gameId)
        internal
        pure
        returns (GameType gameType_, Timestamp timestamp_, address gameProxy_)
    {
        assembly {
            gameType_ := shr(224, _gameId)
            timestamp_ := and(shr(160, _gameId), 0xFFFFFFFFFFFFFFFF)
            gameProxy_ := and(_gameId, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }
}

/// @notice A claim represents an MPT root representing the state of the fault proof program.
type Claim is bytes32;

/// @title LibClaim
/// @notice This library contains helper functions for working with the `Claim` type.
library LibClaim {
    /// @notice Get the value of a `Claim` type in the form of the underlying bytes32.
    /// @param _claim The `Claim` type to get the value of.
    /// @return claim_ The value of the `Claim` type as a bytes32 type.
    function raw(Claim _claim) internal pure returns (bytes32 claim_) {
        assembly {
            claim_ := _claim
        }
    }

    /// @notice Hashes a claim and a position together.
    /// @param _claim A Claim type.
    /// @param _position The position of `claim`.
    /// @param _challengeIndex The index of the claim being moved against.
    /// @return claimHash_ A hash of abi.encodePacked(claim, position|challengeIndex);
    function hashClaimPos(
        Claim _claim,
        Position _position,
        uint256 _challengeIndex
    )
        internal
        pure
        returns (Hash claimHash_)
    {
        assembly {
            mstore(0x00, _claim)
            mstore(0x20, or(shl(128, _position), and(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, _challengeIndex)))
            claimHash_ := keccak256(0x00, 0x40)
        }
    }
}

/// @notice A dedicated duration type.
/// @dev Unit: seconds
type Duration is uint64;

/// @title LibDuration
/// @notice This library contains helper functions for working with the `Duration` type.
library LibDuration {
    /// @notice Get the value of a `Duration` type in the form of the underlying uint64.
    /// @param _duration The `Duration` type to get the value of.
    /// @return duration_ The value of the `Duration` type as a uint64 type.
    function raw(Duration _duration) internal pure returns (uint64 duration_) {
        assembly {
            duration_ := _duration
        }
    }
}

/// @notice A custom type for a generic hash.
type Hash is bytes32;

/// @title LibHash
/// @notice This library contains helper functions for working with the `Hash` type.
library LibHash {
    /// @notice Get the value of a `Hash` type in the form of the underlying bytes32.
    /// @param _hash The `Hash` type to get the value of.
    /// @return hash_ The value of the `Hash` type as a bytes32 type.
    function raw(Hash _hash) internal pure returns (bytes32 hash_) {
        assembly {
            hash_ := _hash
        }
    }
}

/// @notice A dedicated timestamp type.
type Timestamp is uint64;

/// @title LibTimestamp
/// @notice This library contains helper functions for working with the `Timestamp` type.
library LibTimestamp {
    /// @notice Get the value of a `Timestamp` type in the form of the underlying uint64.
    /// @param _timestamp The `Timestamp` type to get the value of.
    /// @return timestamp_ The value of the `Timestamp` type as a uint64 type.
    function raw(Timestamp _timestamp) internal pure returns (uint64 timestamp_) {
        assembly {
            timestamp_ := _timestamp
        }
    }
}

/// @notice A `VMStatus` represents the status of a VM execution.
type VMStatus is uint8;

/// @title LibVMStatus
/// @notice This library contains helper functions for working with the `VMStatus` type.
library LibVMStatus {
    /// @notice Get the value of a `VMStatus` type in the form of the underlying uint8.
    /// @param _vmstatus The `VMStatus` type to get the value of.
    /// @return vmstatus_ The value of the `VMStatus` type as a uint8 type.
    function raw(VMStatus _vmstatus) internal pure returns (uint8 vmstatus_) {
        assembly {
            vmstatus_ := _vmstatus
        }
    }
}

/// @notice A `GameType` represents the type of game being played.
type GameType is uint32;

/// @title LibGameType
/// @notice This library contains helper functions for working with the `GameType` type.
library LibGameType {
    /// @notice Get the value of a `GameType` type in the form of the underlying uint32.
    /// @param _gametype The `GameType` type to get the value of.
    /// @return gametype_ The value of the `GameType` type as a uint32 type.
    function raw(GameType _gametype) internal pure returns (uint32 gametype_) {
        assembly {
            gametype_ := _gametype
        }
    }
}

// lib/optimism/packages/contracts-bedrock/src/dispute/lib/Errors.sol

// Libraries

////////////////////////////////////////////////////////////////
//                `DisputeGameFactory` Errors                 //
////////////////////////////////////////////////////////////////

/// @notice Thrown when a dispute game is attempted to be created with an unsupported game type.
/// @param gameType The unsupported game type.
error NoImplementation(GameType gameType);

/// @notice Thrown when a dispute game that already exists is attempted to be created.
/// @param uuid The UUID of the dispute game that already exists.
error GameAlreadyExists(Hash uuid);

/// @notice Thrown when the root claim has an unexpected VM status.
///         Some games can only start with a root-claim with a specific status.
/// @param rootClaim is the claim that was unexpected.
error UnexpectedRootClaim(Claim rootClaim);

////////////////////////////////////////////////////////////////
//                 `FaultDisputeGame` Errors                  //
////////////////////////////////////////////////////////////////

/// @notice Thrown when a dispute game has already been initialized.
error AlreadyInitialized();

/// @notice Thrown when a supplied bond is not equal to the required bond amount to cover the cost of the interaction.
error IncorrectBondAmount();

/// @notice Thrown when a credit claim is attempted for a value of 0.
error NoCreditToClaim();

/// @notice Thrown when the transfer of credit to a recipient account reverts.
error BondTransferFailed();

/// @notice Thrown when the `extraData` passed to the CWIA proxy is of improper length, or contains invalid information.
error BadExtraData();

/// @notice Thrown when a defense against the root claim is attempted.
error CannotDefendRootClaim();

/// @notice Thrown when a claim is attempting to be made that already exists.
error ClaimAlreadyExists();

/// @notice Thrown when a disputed claim does not match its index in the game.
error InvalidDisputedClaimIndex();

/// @notice Thrown when an action that requires the game to be `IN_PROGRESS` is invoked when
///         the game is not in progress.
error GameNotInProgress();

/// @notice Thrown when a move is attempted to be made after the clock has timed out.
error ClockTimeExceeded();

/// @notice Thrown when the game is attempted to be resolved too early.
error ClockNotExpired();

/// @notice Thrown when a move is attempted to be made at or greater than the max depth of the game.
error GameDepthExceeded();

/// @notice Thrown when a step is attempted above the maximum game depth.
error InvalidParent();

/// @notice Thrown when an invalid prestate is supplied to `step`.
error InvalidPrestate();

/// @notice Thrown when a step is made that computes the expected post state correctly.
error ValidStep();

/// @notice Thrown when a game is attempted to be initialized with an L1 head that does
///         not contain the disputed output root.
error L1HeadTooOld();

/// @notice Thrown when an invalid local identifier is passed to the `addLocalData` function.
error InvalidLocalIdent();

/// @notice Thrown when resolving claims out of order.
error OutOfOrderResolution();

/// @notice Thrown when resolving a claim that has already been resolved.
error ClaimAlreadyResolved();

/// @notice Thrown when a parent output root is attempted to be found on a claim that is in
///         the output root portion of the tree.
error ClaimAboveSplit();

/// @notice Thrown on deployment if the split depth is greater than or equal to the max
///         depth of the game.
error InvalidSplitDepth();

/// @notice Thrown on deployment if the max clock duration is less than or equal to the clock extension.
error InvalidClockExtension();

/// @notice Thrown on deployment if the PreimageOracle challenge period is too high.
error InvalidChallengePeriod();

/// @notice Thrown on deployment if the max depth is greater than `LibPosition.`
error MaxDepthTooLarge();

/// @notice Thrown when trying to step against a claim for a second time, after it has already been countered with
///         an instruction step.
error DuplicateStep();

/// @notice Thrown when an anchor root is not found for a given game type.
error AnchorRootNotFound();

/// @notice Thrown when an output root proof is invalid.
error InvalidOutputRootProof();

/// @notice Thrown when header RLP is invalid with respect to the block hash in an output root proof.
error InvalidHeaderRLP();

/// @notice Thrown when there is a match between the block number in the output root proof and the block number
///         claimed in the dispute game.
error BlockNumberMatches();

/// @notice Thrown when the L2 block number claim has already been challenged.
error L2BlockNumberChallenged();

/// @notice Thrown when the game is not yet finalized.
error GameNotFinalized();

/// @notice Thrown when an invalid bond distribution mode is supplied.
error InvalidBondDistributionMode();

/// @notice Thrown when the game is not yet resolved.
error GameNotResolved();

/// @notice Thrown when a reserved game type is used.
error ReservedGameType();

////////////////////////////////////////////////////////////////
//              `PermissionedDisputeGame` Errors              //
////////////////////////////////////////////////////////////////

/// @notice Thrown when an unauthorized address attempts to interact with the game.
error BadAuth();

/// @notice Thrown when trying to close a game while the system is paused.
error GamePaused();

// lib/optimism/packages/contracts-bedrock/src/dispute/lib/Types.sol

// Libraries

/// @notice The current status of the dispute game.
enum GameStatus {
    // The game is currently in progress, and has not been resolved.
    IN_PROGRESS,
    // The game has concluded, and the `rootClaim` was challenged successfully.
    CHALLENGER_WINS,
    // The game has concluded, and the `rootClaim` could not be contested.
    DEFENDER_WINS
}

/// @notice The game's bond distribution type. Games are expected to start in the `UNDECIDED`
///         state, and then choose either `NORMAL` or `REFUND`.
enum BondDistributionMode {
    // Bond distribution strategy has not been chosen.
    UNDECIDED,
    // Bonds should be distributed as normal.
    NORMAL,
    // Bonds should be refunded to claimants.
    REFUND
}

/// @notice Represents an L2 root and the L2 sequence number at which it was generated.
/// @custom:field root The output root.
/// @custom:field l2SequenceNumber The L2 Sequence Number ( e.g. block number / timestamp) at which the root was
/// generated.
struct Proposal {
    Hash root;
    uint256 l2SequenceNumber;
}

/// @title GameTypes
/// @notice A library that defines the IDs of games that can be played.
library GameTypes {
    /// @dev A dispute game type the uses the cannon vm.
    GameType internal constant CANNON = GameType.wrap(0);

    /// @dev A permissioned dispute game type that uses the cannon vm.
    GameType internal constant PERMISSIONED_CANNON = GameType.wrap(1);

    /// @notice A dispute game type that uses the asterisc vm.
    GameType internal constant ASTERISC = GameType.wrap(2);

    /// @notice A dispute game type that uses the asterisc vm with Kona.
    GameType internal constant ASTERISC_KONA = GameType.wrap(3);

    /// @notice A dispute game type that uses the cannon vm (Super Roots).
    GameType internal constant SUPER_CANNON = GameType.wrap(4);

    /// @notice A dispute game type that uses the permissioned cannon vm (Super Roots).
    GameType internal constant SUPER_PERMISSIONED_CANNON = GameType.wrap(5);

    /// @notice A dispute game type that uses OP Succinct
    GameType internal constant OP_SUCCINCT = GameType.wrap(6);

    /// @notice A dispute game type that uses the asterisc vm with Kona (Super Roots).
    GameType internal constant SUPER_ASTERISC_KONA = GameType.wrap(7);

    /// @notice A dispute game type that uses the cannon vm with Kona.
    GameType internal constant CANNON_KONA = GameType.wrap(8);

    /// @notice A dispute game type that uses the cannon vm with Kona (Super Roots).
    GameType internal constant SUPER_CANNON_KONA = GameType.wrap(9);

    /// @notice A dispute game type with short game duration for testing withdrawals.
    ///         Not intended for production use.
    GameType internal constant FAST = GameType.wrap(254);

    /// @notice A dispute game type that uses an alphabet vm.
    ///         Not intended for production use.
    GameType internal constant ALPHABET = GameType.wrap(255);

    /// @notice A dispute game type that uses RISC Zero's Kailua
    GameType internal constant KAILUA = GameType.wrap(1337);
}

/// @title VMStatuses
/// @notice Named type aliases for the various valid VM status bytes.
library VMStatuses {
    /// @notice The VM has executed successfully and the outcome is valid.
    VMStatus internal constant VALID = VMStatus.wrap(0);

    /// @notice The VM has executed successfully and the outcome is invalid.
    VMStatus internal constant INVALID = VMStatus.wrap(1);

    /// @notice The VM has paniced.
    VMStatus internal constant PANIC = VMStatus.wrap(2);

    /// @notice The VM execution is still in progress.
    VMStatus internal constant UNFINISHED = VMStatus.wrap(3);
}

/// @title LocalPreimageKey
/// @notice Named type aliases for local `PreimageOracle` key identifiers.
library LocalPreimageKey {
    /// @notice The identifier for the L1 head hash.
    uint256 internal constant L1_HEAD_HASH = 0x01;

    /// @notice The identifier for the starting output root.
    uint256 internal constant STARTING_OUTPUT_ROOT = 0x02;

    /// @notice The identifier for the disputed output root.
    uint256 internal constant DISPUTED_OUTPUT_ROOT = 0x03;

    /// @notice The identifier for the disputed L2 block number.
    uint256 internal constant DISPUTED_L2_BLOCK_NUMBER = 0x04;

    /// @notice The identifier for the chain ID.
    uint256 internal constant CHAIN_ID = 0x05;
}

// src/KailuaLib.sol
// Copyright 2024, 2025 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// @notice Denotes the proven status of the game
/// @custom:value NONE indicates that no proof has been submitted yet.
enum ProofStatus {
    NONE,
    FAULT,
    VALIDITY
}

// 0xd36871fd
/// @notice Thrown when a blacklisted address attempts to interact with the game.
error Blacklisted(address source, address expected);

// 0x9d3e7d24
/// @notice Thrown when a child from an unknown source appends itself to a tournament
error UnknownGame();

// 0x8b1dfa22
/// @notice Thrown when eliminating an already removed child
error AlreadyEliminated();

// 0x2c06a364
/// @notice Thrown when a proof is submitted for an already proven game
error AlreadyProven();

// 0xa506d334
/// @notice Thrown when a resolution is attempted for an unproven claim
error NotProven();

// 0x5e22e582
/// @notice Thrown when resolving a faulty proposal
error ProvenFaulty();

// 0xf2a87d5e
/// @notice Thrown when pruning is attempted with no children
error NotProposed();

// 0x7412124e
/// @notice Thrown when proving is attempted with two agreeing outputs
error NoConflict();

// 0x9276ab5a
/// @notice Thrown when proposing before the minimum creation time
error ProposalGapRemaining(uint256 currentTime, uint256 minCreationTime);

// 0x1434391f
/// @notice Thrown when a blob hash is missing
error BlobHashMissing(uint256 index, uint256 count);

// 0x19e3a1dc
/// @notice Occurs when the duplication counter is wrong
error InvalidDuplicationCounter();

// 0xeaa0996e
/// @notice Occurs when the anchored game block number is different
/// @param anchored The L2 block number of the anchored game
/// @param initialized This game's l2 block number
error BlockNumberMismatch(uint256 anchored, uint256 initialized);

// 0x627fad6e
/// @notice Occurs when a proposer attempts to extend the chain before the vanguard
/// @param parentGame The address of the parent proposal being extended
error VanguardError(address parentGame);

// 0x428e0b92
/// @notice Thrown when a non-factory owner calls an owner-only function.
error NotFactoryOwner();

interface IKailuaTreasury {
    /// @notice Emitted when the participation bond is updated
    /// @param amount The new required bond amount
    event BondUpdated(uint256 amount);

    /// @notice Returns the game index at which proposer was proven faulty
    function eliminationRound(address proposer) external view returns (uint256);

    /// @notice Returns the proposer of a game
    function proposerOf(address game) external view returns (address);

    /// @notice Eliminates a child's proposer and allocates their bond to the prover
    function eliminate(address child, address prover) external;

    /// @notice Returns true iff a proposal is currently being submitted
    function isProposing() external view returns (bool);

    /// @notice Returns the last resolved proposal contract address
    function lastResolved() external view returns (address);

    /// @notice Updates the last resolved contract address to that of the caller
    function updateLastResolved() external;

    /// @notice Returns the collateral required to submit proposals
    function participationBond() external view returns (uint256);

    /// @notice Returns the prover's number of shares in elimination rewards
    function ELIMINATION_SPLIT_PROVER_NUM() external view returns (uint256);

    /// @notice Returns the total number of shares for elimination rewards
    function ELIMINATION_SPLIT_DENOM() external view returns (uint256);
}

interface IKailuaTournament {
    /// @notice Emitted when a proof is submitted.
    /// @param signature The proposal signature
    /// @param status The proven status
    event Proven(bytes32 indexed signature, ProofStatus indexed status);

    /// @notice Returns the KailuaTreasury of this tournament
    function KAILUA_TREASURY() external view returns (IKailuaTreasury);
    /// @notice The timestamp of when the first proof for a proposal signature was made
    function provenAt(bytes32) external view returns (Timestamp);
    /// @notice Returns the hash of the output claim and all blob hashes associated with this proposal
    function signature() external view returns (bytes32);
    /// @notice Returns whether a child can be considered valid
    function isViableSignature(bytes32 childSignature) external view returns (bool);
    /// @notice Returns the signature of the child proven valid
    function validChildSignature() external view returns (bytes32);
}

library KailuaPayLib {
    /// @notice Transfers ETH from the contract's balance to the recipient
    function pay(uint256 amount, address recipient) internal {
        (bool success,) = recipient.call{value: amount}(hex"");
        if (!success) revert BondTransferFailed();
    }
}

library KailuaKZGLib {
    /// @notice The KZG commitment version
    bytes32 internal constant KZG_COMMITMENT_VERSION =
        bytes32(0x0100000000000000000000000000000000000000000000000000000000000000);

    /// @notice The modular exponentiation precompile
    address internal constant MOD_EXP = address(0x05);

    /// @notice The point evaluation precompile
    address internal constant KZG = address(0x0a);

    /// @notice The expected result from the point evaluation precompile
    bytes32 internal constant KZG_RESULT = keccak256(abi.encodePacked(FIELD_ELEMENTS_PER_BLOB, BLS_MODULUS));

    /// @notice Scalar field modulus of BLS12-381
    uint256 internal constant BLS_MODULUS =
        52435875175126190479447740508185965837690552500527637822603658699938581184513;

    /// @notice The base root of unity for indexing blob field elements
    uint256 internal constant ROOT_OF_UNITY =
        39033254847818212395286706435128746857159659164139250548781411570340225835782;

    /// @notice The po2 for the number of field elements in a single blob
    uint256 internal constant FIELD_ELEMENTS_PER_BLOB_PO2 = 12;

    /// @notice The number of field elements in a single blob
    uint256 internal constant FIELD_ELEMENTS_PER_BLOB = uint64(1 << FIELD_ELEMENTS_PER_BLOB_PO2);

    /// @notice The index of the blob containing the FE at the provided offset
    function blobIndex(uint256 outputOffset) internal pure returns (uint256 index) {
        index = outputOffset / FIELD_ELEMENTS_PER_BLOB;
    }

    /// @notice The index of the FE at the provided offset in the blob that contains it
    function fieldElementIndex(uint256 outputOffset) internal pure returns (uint32 position) {
        position = uint32(outputOffset % FIELD_ELEMENTS_PER_BLOB);
    }

    /// @notice The versioned KZG hash of the provided blob commitment
    function versionedKZGHash(bytes calldata blobCommitment) internal pure returns (bytes32 hash) {
        require(blobCommitment.length == 48);
        hash = ((sha256(blobCommitment) << 8) >> 8) | KZG_COMMITMENT_VERSION;
    }

    /// @notice The mapped FE corresponding to the input hash
    function hashToFe(bytes32 hash) internal pure returns (uint256 fe) {
        fe = uint256(hash) % BLS_MODULUS;
    }

    /// @notice Returns true iff the proof shows that the FE is part of the blob at the provided position
    function verifyKZGBlobProof(
        bytes32 versionedBlobHash,
        uint32 index,
        uint256 value,
        bytes calldata blobCommitment,
        bytes calldata proof
    ) internal view returns (bool success) {
        uint256 rootOfUnity = modExp(reverseBits(index));
        // Byte range	Name	        Description
        // [0:32]	    versioned_hash	Reference to a blob in the execution layer.
        // [32:64]	    x	            x-coordinate at which the blob is being evaluated.
        // [64:96]	    y	            y-coordinate at which the blob is being evaluated.
        // [96:144]	    commitment	    Commitment to the blob being evaluated.
        // [144:192]	proof	        Proof associated with the commitment.
        bytes memory kzgCallData = abi.encodePacked(versionedBlobHash, rootOfUnity, value, blobCommitment, proof);
        // The precompile will reject non-canonical field elements (i.e. value must be less than BLS_MODULUS).
        (bool _success, bytes memory kzgResult) = KZG.staticcall(kzgCallData);
        // Validate the precompile response
        require(keccak256(kzgResult) == KZG_RESULT);
        // Return the result
        success = _success;
    }

    /// @notice Calls the modular exponentiation precompile with a fixed base and modulus
    function modExp(uint256 exponent) internal view returns (uint256 result) {
        bytes memory modExpData =
            abi.encodePacked(uint256(32), uint256(32), uint256(32), ROOT_OF_UNITY, exponent, BLS_MODULUS);
        (bool success, bytes memory mexpResult) = MOD_EXP.staticcall(modExpData);
        require(success);
        result = uint256(bytes32(mexpResult));
    }

    /// @notice Reverses the bits of the input index
    function reverseBits(uint32 index) internal pure returns (uint256 result) {
        for (uint256 i = 0; i < FIELD_ELEMENTS_PER_BLOB_PO2; i++) {
            result <<= 1;
            result |= ((1 << i) & index) >> i;
        }
    }
}

// src/KailuaVerifier.sol
// Copyright 2025 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// @notice Thrown when a target is invalid
error BadTarget();

contract KailuaVerifier is ISemver {
    /// @notice Semantic version.
    /// @custom:semver 1.2.0
    string public constant version = "1.2.0";

    /// @notice The RISC Zero verifier contract
    IRiscZeroVerifier public immutable RISC_ZERO_VERIFIER;

    /// @notice The RISC Zero image id of the fault proof program
    bytes32 public immutable FPVM_IMAGE_ID;

    /// @notice The hash of the game configuration
    bytes32 public immutable ROLLUP_CONFIG_HASH;

    /// @notice The duration after which a permit expires
    Duration public immutable PERMIT_DURATION;

    /// @notice The duration after which a permit is active
    Duration public immutable PERMIT_DELAY;

    constructor(
        IRiscZeroVerifier _verifierContract,
        bytes32 _imageId,
        bytes32 _configHash,
        Duration _permitDuration,
        Duration _permitDelay
    ) {
        RISC_ZERO_VERIFIER = _verifierContract;
        FPVM_IMAGE_ID = _imageId;
        ROLLUP_CONFIG_HASH = _configHash;
        PERMIT_DURATION = _permitDuration;
        PERMIT_DELAY = _permitDelay;
        assert(_permitDelay.raw() < _permitDuration.raw());
    }

    /// @notice Maps parent-child to their fault proving permits
    mapping(bytes32 => FaultProofPermit[]) public faultProofPermits;

    /// @notice Describes a permit for fault proving
    /// @custom:field recipient             Address of the permit recipient
    /// @custom:field aggregateCollateral   Total collateral locked as of permit
    /// @custom:field timestamp             Timestamp of permit issuance
    /// @custom:field released              Flag for whether the collateral locked for this permit
    struct FaultProofPermit {
        uint256 aggregateCollateral;
        address recipient;
        uint64 timestamp;
        bool released;
    }

    /// @notice Returns the key for indexing fault proving permits
    function faultProofPermitKey(IKailuaTournament proposalParent, bytes32 proposalSignature)
        public
        pure
        returns (bytes32)
    {
        return sha256(abi.encodePacked(address(proposalParent), proposalSignature));
    }

    /// @notice Returns the earliest timestamp at which a fault proof permit can be released
    function faultProofPermitProvenAt(IKailuaTournament proposalParent, bytes32 proposalSignature)
        public
        view
        returns (uint64)
    {
        // INVARIANT: A validity proof for the same signature does not satisfy a fault proof permit.
        bytes32 validChildSignature = proposalParent.validChildSignature();
        if (proposalSignature == validChildSignature) {
            return 0;
        }
        // Fetch both fault and validity proof timestamps
        uint64 faultProofTimestamp = proposalParent.provenAt(proposalSignature).raw();
        uint64 validityProofTimestamp = proposalParent.provenAt(validChildSignature).raw();
        // Return the smaller timestamp if both proofs are present
        if (faultProofTimestamp > 0 && validityProofTimestamp > 0) {
            return faultProofTimestamp < validityProofTimestamp ? faultProofTimestamp : validityProofTimestamp;
        }
        // Return the larger timestamp otherwise
        return faultProofTimestamp > validityProofTimestamp ? faultProofTimestamp : validityProofTimestamp;
    }

    /// @notice Returns the exclusive beneficiary of a fault proof reward
    function faultProofPermitBeneficiary(IKailuaTournament proposalParent, bytes32 proposalSignature)
        public
        view
        returns (address)
    {
        // If the signature is still viable, there is no sole fault proof beneficiary
        if (proposalParent.isViableSignature(proposalSignature)) {
            return address(0x0);
        }
        // If there wasn't exactly one permit, then proving was not exclusive to one party
        FaultProofPermit[] storage proposalPermits =
            faultProofPermits[faultProofPermitKey(proposalParent, proposalSignature)];
        if (proposalPermits.length != 1) {
            return address(0x0);
        }
        // If the permit was not yet active at proof submission, ignore the permit
        uint64 provingTime = faultProofPermitProvenAt(proposalParent, proposalSignature);
        if (provingTime < proposalPermits[0].timestamp + PERMIT_DELAY.raw()) {
            return address(0x0);
        }
        // If there was no proof or the permit was expired as of proof submission, disqualify the beneficiary
        if (provingTime == 0 || proposalPermits[0].timestamp + PERMIT_DURATION.raw() < provingTime) {
            return address(0x0);
        }
        // Return the successful sole beneficiary of the locked fault proof reward
        return proposalPermits[0].recipient;
    }

    /// @notice Given a reference timestamp, returns the number of expired permits, the number of delayed permits,
    /// the total expired permit collateral, and the number of active permits
    function countExpiredPermits(
        bytes32 proposalKey,
        uint64 numExpiredPermits,
        uint64 numDelayedPermits,
        uint64 timestamp
    ) public view returns (uint64, uint64, uint256, uint64) {
        FaultProofPermit[] storage proposalPermits = faultProofPermits[proposalKey];
        uint256 expiredCollateral = 0;
        uint64 totalPermits = uint64(proposalPermits.length);
        if (totalPermits == 0) {
            // If there are no permits, no permit is expired or active, and there is no collateral
            return (0, 0, 0, 0);
        }
        // Increment numExpiredPermits if possible
        for (; numExpiredPermits < totalPermits; numExpiredPermits++) {
            if (proposalPermits[numExpiredPermits].timestamp + PERMIT_DURATION.raw() >= timestamp) {
                break;
            }
        }
        // Validate expiry
        if (numExpiredPermits > 0) {
            // If numExpiredPermits is invalid, revert
            if (proposalPermits[numExpiredPermits - 1].timestamp + PERMIT_DURATION.raw() >= timestamp) {
                revert BadTarget();
            }
            // Set expired collateral
            expiredCollateral = proposalPermits[numExpiredPermits - 1].aggregateCollateral;
        }
        // Increment numDelayedPermits if possible
        for (; numDelayedPermits < totalPermits; numDelayedPermits++) {
            // If this permit is active, stop incrementing
            if (proposalPermits[totalPermits - numDelayedPermits - 1].timestamp + PERMIT_DELAY.raw() <= timestamp) {
                break;
            }
        }
        // Decrement numDelayedPermits if possible
        numDelayedPermits = numDelayedPermits > totalPermits ? totalPermits : numDelayedPermits;
        for (; numDelayedPermits > 0 && numDelayedPermits <= totalPermits; numDelayedPermits--) {
            // If this permit is delayed, stop decrementing
            if (proposalPermits[totalPermits - numDelayedPermits].timestamp + PERMIT_DELAY.raw() > timestamp) {
                break;
            }
        }
        return
            (
                numExpiredPermits,
                numDelayedPermits,
                expiredCollateral,
                totalPermits - numExpiredPermits - numDelayedPermits
            );
    }

    /// @notice Returns the collateral required to acquire a fault proof permit
    function faultProofPermitBond(IKailuaTreasury treasury) public view returns (uint256 bond) {
        bond = (treasury.participationBond() * 2 * treasury.ELIMINATION_SPLIT_PROVER_NUM())
            / treasury.ELIMINATION_SPLIT_DENOM();
    }

    /// @notice Locks the right to submit a fault proof for a given proposal signature
    /// @dev Do not call this function to acquire locks for faults that will not lead to elimination.
    function acquireFaultProofPermit(
        IKailuaTournament proposalParent,
        bytes32 proposalSignature,
        uint64 numExpiredPermits,
        uint64 numDelayedPermits,
        address payoutRecipient
    ) external payable returns (uint256 totalPermitsIssued_) {
        // INVARIANT: The child signature is still viable so no proof is submitted for/against it
        if (!proposalParent.isViableSignature(proposalSignature)) {
            revert ProvenFaulty();
        }
        // INVARIANT: The collateral submitted for the permit covers two times the proving reward
        IKailuaTreasury treasury = proposalParent.KAILUA_TREASURY();
        if (msg.value < faultProofPermitBond(treasury)) {
            revert IncorrectBondAmount();
        }
        // INVARIANT: There are exactly numExpiredPermits expired permits as of block.timestamp
        bytes32 proposalKey = faultProofPermitKey(proposalParent, proposalSignature);
        (numExpiredPermits,,,) =
            countExpiredPermits(proposalKey, numExpiredPermits, numDelayedPermits, uint64(block.timestamp));
        // INVARIANT: There is at least one permit available
        FaultProofPermit[] storage proposalPermits = faultProofPermits[proposalKey];
        totalPermitsIssued_ = proposalPermits.length;
        if (totalPermitsIssued_ > 2 * numExpiredPermits) {
            revert ClockNotExpired();
        }
        // Calculate the aggregate collateral value
        uint256 aggregateCollateral = msg.value;
        if (totalPermitsIssued_ > 0) {
            aggregateCollateral += proposalPermits[totalPermitsIssued_ - 1].aggregateCollateral;
        }
        // Assign a new permit
        proposalPermits.push(FaultProofPermit(aggregateCollateral, payoutRecipient, uint64(block.timestamp), false));
    }

    /// @notice Claims the total payout for a permit
    function releaseFaultProofPermit(
        IKailuaTournament proposalParent,
        bytes32 proposalSignature,
        uint64 numExpiredPermits,
        uint64 numDelayedPermits,
        uint64 permitIndex
    ) external {
        // INVARIANT: The child signature is proven faulty
        if (proposalParent.isViableSignature(proposalSignature)) {
            revert NotProven();
        }
        // INVARIANT: There are exactly numExpiredPermits expired permits as of proof submission
        uint64 proofTimestamp = faultProofPermitProvenAt(proposalParent, proposalSignature);
        bytes32 permitKey = faultProofPermitKey(proposalParent, proposalSignature);
        (,, uint256 expiredCollateral, uint64 numActivePermits) =
            countExpiredPermits(permitKey, numExpiredPermits, numDelayedPermits, proofTimestamp);
        // INVARIANT: The permit is not already released
        FaultProofPermit storage permit = faultProofPermits[permitKey][permitIndex];
        if (permit.released) {
            revert NoCreditToClaim();
        }
        // INVARIANT: The permit is not expired as of proof submission
        if (permit.timestamp + PERMIT_DURATION.raw() < proofTimestamp) {
            revert AlreadyEliminated();
        }
        // If the permit was active at proof submission, then we pay out a share of the locked collateral.
        uint256 payout =
            permit.timestamp + PERMIT_DELAY.raw() < proofTimestamp ? expiredCollateral / numActivePermits : 0;
        // Add in recipient's own deposited collateral
        if (permitIndex > 0) {
            payout += permit.aggregateCollateral - faultProofPermits[permitKey][permitIndex - 1].aggregateCollateral;
        } else {
            payout += permit.aggregateCollateral;
        }
        // Pay out recipient
        permit.released = true;
        KailuaPayLib.pay(payout, payable(permit.recipient));
    }

    /// @notice Verifies a ZK proof
    function verify(
        address payoutRecipient,
        bytes32 preconditionHash,
        bytes32 l1Head,
        bytes32 agreedL2OutputRoot,
        bytes32 claimedL2OutputRoot,
        uint64 claimedL2BlockNumber,
        bytes calldata encodedSeal
    ) external view {
        // Construct the expected journal
        bytes memory journal = abi.encodePacked(
            // The address of the recipient of the payout for this proof
            payoutRecipient,
            // The blob equivalence precondition hash
            preconditionHash,
            // The L1 head hash containing the safe L2 chain data that may reproduce the L2 head hash.
            l1Head,
            // The accepted output
            agreedL2OutputRoot,
            // The proposed output
            claimedL2OutputRoot,
            // The claim block number
            claimedL2BlockNumber,
            // The rollup configuration hash
            ROLLUP_CONFIG_HASH,
            // The FPVM Image ID
            FPVM_IMAGE_ID
        );

        // Revert on proof verification failure
        RISC_ZERO_VERIFIER.verify(encodedSeal, FPVM_IMAGE_ID, sha256(journal));
    }
}
