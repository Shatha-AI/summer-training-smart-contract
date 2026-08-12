// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity =0.8.16 >=0.5.12 ^0.8.16;

// lib/dss-exec-lib/src/CollateralOpts.sol

//
// CollateralOpts.sol -- Data structure for onboarding collateral
//
// Copyright (C) 2020-2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

struct CollateralOpts {
    bytes32 ilk;
    address gem;
    address join;
    address clip;
    address calc;
    address pip;
    bool    isLiquidatable;
    bool    isOSM;
    bool    whitelistOSM;
    uint256 ilkDebtCeiling;
    uint256 minVaultAmount;
    uint256 maxLiquidationAmount;
    uint256 liquidationPenalty;
    uint256 ilkStabilityFee;
    uint256 startingPriceFactor;
    uint256 breakerTolerance;
    uint256 auctionDuration;
    uint256 permittedDrop;
    uint256 liquidationRatio;
    uint256 kprFlatReward;
    uint256 kprPctReward;
}

// lib/dss-test/lib/dss-interfaces/src/dss/DssAutoLineAbstract.sol

// https://github.com/makerdao/dss-auto-line/blob/master/src/DssAutoLine.sol
interface DssAutoLineAbstract {
    function wards(address) external view returns (uint256);
    function rely(address) external;
    function deny(address) external;
    function vat() external view returns (address);
    function ilks(bytes32) external view returns (uint256,uint256,uint48,uint48,uint48);
    function setIlk(bytes32,uint256,uint256,uint256) external;
    function remIlk(bytes32) external;
    function exec(bytes32) external returns (uint256);
}

// lib/dss-exec-lib/src/DssExec.sol

//
// DssExec.sol -- MakerDAO Executive Spell Template
//
// Copyright (C) 2020-2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

interface PauseAbstract {
    function delay() external view returns (uint256);
    function plot(address, bytes32, bytes calldata, uint256) external;
    function exec(address, bytes32, bytes calldata, uint256) external returns (bytes memory);
}

interface Changelog {
    function getAddress(bytes32) external view returns (address);
}

interface SpellAction {
    function officeHours() external view returns (bool);
    function description() external view returns (string memory);
    function nextCastTime(uint256) external view returns (uint256);
}

contract DssExec {

    Changelog      constant public log   = Changelog(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);
    uint256                 public eta;
    bytes                   public sig;
    bool                    public done;
    bytes32       immutable public tag;
    address       immutable public action;
    uint256       immutable public expiration;
    PauseAbstract immutable public pause;

    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: seth keccak -- "$(wget https://<executive-vote-canonical-post> -q -O - 2>/dev/null)"
    function description() external view returns (string memory) {
        return SpellAction(action).description();
    }

    function officeHours() external view returns (bool) {
        return SpellAction(action).officeHours();
    }

    function nextCastTime() external view returns (uint256 castTime) {
        return SpellAction(action).nextCastTime(eta);
    }

    // @param _description  A string description of the spell
    // @param _expiration   The timestamp this spell will expire. (Ex. block.timestamp + 30 days)
    // @param _spellAction  The address of the spell action
    constructor(uint256 _expiration, address _spellAction) {
        pause       = PauseAbstract(log.getAddress("MCD_PAUSE"));
        expiration  = _expiration;
        action      = _spellAction;

        sig = abi.encodeWithSignature("execute()");
        bytes32 _tag;                    // Required for assembly access
        address _action = _spellAction;  // Required for assembly access
        assembly { _tag := extcodehash(_action) }
        tag = _tag;
    }

    function schedule() public {
        require(block.timestamp <= expiration, "This contract has expired");
        require(eta == 0, "This spell has already been scheduled");
        eta = block.timestamp + PauseAbstract(pause).delay();
        pause.plot(action, tag, sig, eta);
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        pause.exec(action, tag, sig, eta);
    }
}

// lib/dss-test/lib/dss-interfaces/src/ERC/GemAbstract.sol

// A base ERC-20 abstract class
// https://eips.ethereum.org/EIPS/eip-20
interface GemAbstract {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// lib/dss-test/lib/dss-interfaces/src/dss/JugAbstract.sol

// https://github.com/makerdao/dss/blob/master/src/jug.sol
interface JugAbstract {
    function wards(address) external view returns (uint256);
    function rely(address) external;
    function deny(address) external;
    function ilks(bytes32) external view returns (uint256, uint256);
    function vat() external view returns (address);
    function vow() external view returns (address);
    function base() external view returns (uint256);
    function init(bytes32) external;
    function file(bytes32, bytes32, uint256) external;
    function file(bytes32, uint256) external;
    function file(bytes32, address) external;
    function drip(bytes32) external returns (uint256);
}

// lib/dss-test/lib/dss-interfaces/src/dss/mip21/RwaLiquidationOracleAbstract.sol
// SPDX-FileCopyrightText: © 2022 Dai Foundation <www.daifoundation.org>

// https://github.com/makerdao/mip21-toolkit/blob/master/src/oracles/RwaLiquidationOracle.sol
interface RwaLiquidationOracleAbstract {
    function wards(address) external view returns (uint256);
    function rely(address) external;
    function deny(address) external;
    function vat() external view returns (address);
    function vow() external view returns (address);
    function ilks(bytes32) external view returns(string memory, address, uint48, uint48);
    function file(bytes32, address) external;
    function init(bytes32, uint256, string calldata, uint48) external;
    function bump(bytes32, uint256) external;
    function tell(bytes32) external;
    function cure(bytes32) external;
    function cull(bytes32, address) external;
    function good(bytes32) external view returns (bool);
}

// src/dependencies/endgame-toolkit/StakingRewardsInit.sol

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

struct StakingRewardsInitParams {
    address dist;
}

struct StakingRewardsNominateNewOwnerParams {
    address newOwner;
}

library StakingRewardsInit {
    function init(address rewards, StakingRewardsInitParams memory p) internal {
        StakingRewardsLike_0(rewards).setRewardsDistribution(p.dist);
    }

    /// @dev `StakingRewards` ownership transfer is a 2-step process: nominate + acceptance.
    function nominateNewOwner(address rewards, StakingRewardsNominateNewOwnerParams memory p) internal {
        StakingRewardsLike_0(rewards).nominateNewOwner(p.newOwner);
    }

    /// @dev `StakingRewards` ownership transfer requires the new owner to explicitly accept it.
    function acceptOwnership(address rewards) internal {
        StakingRewardsLike_0(rewards).acceptOwnership();
    }
}

interface StakingRewardsLike_0 {
    function setRewardsDistribution(address _rewardsDistribution) external;

    function acceptOwnership() external;

    function nominateNewOwner(address _owner) external;
}

// lib/dss-test/lib/dss-interfaces/src/dss/VatAbstract.sol

// https://github.com/makerdao/dss/blob/master/src/vat.sol
interface VatAbstract {
    function wards(address) external view returns (uint256);
    function rely(address) external;
    function deny(address) external;
    function can(address, address) external view returns (uint256);
    function hope(address) external;
    function nope(address) external;
    function ilks(bytes32) external view returns (uint256, uint256, uint256, uint256, uint256);
    function urns(bytes32, address) external view returns (uint256, uint256);
    function gem(bytes32, address) external view returns (uint256);
    function dai(address) external view returns (uint256);
    function sin(address) external view returns (uint256);
    function debt() external view returns (uint256);
    function vice() external view returns (uint256);
    function Line() external view returns (uint256);
    function live() external view returns (uint256);
    function init(bytes32) external;
    function file(bytes32, uint256) external;
    function file(bytes32, bytes32, uint256) external;
    function cage() external;
    function slip(bytes32, address, int256) external;
    function flux(bytes32, address, address, uint256) external;
    function move(address, address, uint256) external;
    function frob(bytes32, address, address, address, int256, int256) external;
    function fork(bytes32, address, address, int256, int256) external;
    function grab(bytes32, address, address, address, int256, int256) external;
    function heal(uint256) external;
    function suck(address, address, uint256) external;
    function fold(bytes32, address, int256) external;
}

// src/dependencies/endgame-toolkit/VestInit.sol

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

struct VestCreateParams {
    address usr;
    uint256 tot;
    uint256 bgn;
    uint256 tau;
    uint256 eta;
}

/// @dev Handles vesting stream creation. Assumes `DssVest` parameters are initialized somewhere else.
library VestInit {
    function create(address vest, VestCreateParams memory p) internal returns (uint256 vestId) {
        vestId = DssVestLike(vest).create(
            p.usr,
            p.tot,
            p.bgn,
            p.tau,
            p.eta,
            address(0) // mgr
        );

        DssVestLike(vest).restrict(vestId);
    }
}

interface DssVestLike {
    function create(
        address _usr,
        uint256 _tot,
        uint256 _bgn,
        uint256 _tau,
        uint256 _eta,
        address _mgr
    ) external returns (uint256 id);

    function restrict(uint256 _id) external;
}

// src/dependencies/endgame-toolkit/VestedRewardsDistributionInit.sol

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

struct VestedRewardsDistributionInitParams {
    uint256 vestId;
}

library VestedRewardsDistributionInit {
    function init(address dist, VestedRewardsDistributionInitParams memory p) internal {
        VestedRewardsDistributionLike_0(dist).file("vestId", p.vestId);
    }
}

interface VestedRewardsDistributionLike_0 {
    function file(bytes32 what, uint256 data) external;
}

// lib/dss-exec-lib/src/DssExecLib.sol

//
// DssExecLib.sol -- MakerDAO Executive Spellcrafting Library
//
// Copyright (C) 2020-2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

interface Initializable {
    function init(bytes32) external;
}

interface Authorizable {
    function rely(address) external;
    function deny(address) external;
    function setAuthority(address) external;
}

interface Fileable {
    function file(bytes32, address) external;
    function file(bytes32, uint256) external;
    function file(bytes32, bytes32, uint256) external;
    function file(bytes32, bytes32, address) external;
}

interface Drippable {
    function drip() external returns (uint256);
    function drip(bytes32) external returns (uint256);
}

interface Pricing {
    function poke(bytes32) external;
}

interface ERC20 {
    function decimals() external returns (uint8);
}

interface DssVat {
    function hope(address) external;
    function nope(address) external;
    function ilks(bytes32) external returns (uint256 Art, uint256 rate, uint256 spot, uint256 line, uint256 dust);
    function Line() external view returns (uint256);
    function suck(address, address, uint256) external;
}

interface ClipLike {
    function vat() external returns (address);
    function dog() external returns (address);
    function spotter() external view returns (address);
    function calc() external view returns (address);
    function ilk() external returns (bytes32);
}

interface DogLike {
    function ilks(bytes32) external returns (address clip, uint256 chop, uint256 hole, uint256 dirt);
}

interface JoinLike {
    function vat() external returns (address);
    function ilk() external returns (bytes32);
    function gem() external returns (address);
    function dec() external returns (uint256);
    function join(address, uint256) external;
    function exit(address, uint256) external;
}

// Includes Median and OSM functions
interface OracleLike_0 {
    function src() external view returns (address);
    function lift(address[] calldata) external;
    function drop(address[] calldata) external;
    function setBar(uint256) external;
    function kiss(address) external;
    function diss(address) external;
    function kiss(address[] calldata) external;
    function diss(address[] calldata) external;
    function orb0() external view returns (address);
    function orb1() external view returns (address);
}

interface MomLike {
    function setOsm(bytes32, address) external;
    function setPriceTolerance(address, uint256) external;
}

interface RegistryLike {
    function add(address) external;
    function xlip(bytes32) external view returns (address);
}

// https://github.com/makerdao/dss-chain-log
interface ChainlogLike_0 {
    function setVersion(string calldata) external;
    function setIPFS(string calldata) external;
    function setSha256sum(string calldata) external;
    function getAddress(bytes32) external view returns (address);
    function setAddress(bytes32, address) external;
    function removeAddress(bytes32) external;
}

interface IAMLike {
    function ilks(bytes32) external view returns (uint256,uint256,uint48,uint48,uint48);
    function setIlk(bytes32,uint256,uint256,uint256) external;
    function remIlk(bytes32) external;
    function exec(bytes32) external returns (uint256);
}

interface LerpFactoryLike {
    function newLerp(bytes32 name_, address target_, bytes32 what_, uint256 startTime_, uint256 start_, uint256 end_, uint256 duration_) external returns (address);
    function newIlkLerp(bytes32 name_, address target_, bytes32 ilk_, bytes32 what_, uint256 startTime_, uint256 start_, uint256 end_, uint256 duration_) external returns (address);
}

interface LerpLike {
    function tick() external returns (uint256);
}

interface RwaOracleLike {
    function bump(bytes32 ilk, uint256 val) external;
}

library DssExecLib {

    /*****************/
    /*** Constants ***/
    /*****************/
    address constant public LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    uint256 constant internal WAD      = 10 ** 18;
    uint256 constant internal RAY      = 10 ** 27;
    uint256 constant internal RAD      = 10 ** 45;
    uint256 constant internal THOUSAND = 10 ** 3;
    uint256 constant internal MILLION  = 10 ** 6;

    uint256 constant internal BPS_ONE_PCT             = 100;
    uint256 constant internal BPS_ONE_HUNDRED_PCT     = 100 * BPS_ONE_PCT;
    uint256 constant internal RATES_ONE_HUNDRED_PCT   = 1000000021979553151239153027;

    /**********************/
    /*** Math Functions ***/
    /**********************/
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x * WAD + y / 2) / y;
    }
    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x * RAY + y / 2) / y;
    }

    /****************************/
    /*** Core Address Helpers ***/
    /****************************/
    function dai()        public view returns (address) { return getChangelogAddress("MCD_DAI"); }
    function mkr()        public view returns (address) { return getChangelogAddress("MCD_GOV"); }
    function vat()        public view returns (address) { return getChangelogAddress("MCD_VAT"); }
    function cat()        public view returns (address) { return getChangelogAddress("MCD_CAT"); }
    function dog()        public view returns (address) { return getChangelogAddress("MCD_DOG"); }
    function jug()        public view returns (address) { return getChangelogAddress("MCD_JUG"); }
    function pot()        public view returns (address) { return getChangelogAddress("MCD_POT"); }
    function vow()        public view returns (address) { return getChangelogAddress("MCD_VOW"); }
    function end()        public view returns (address) { return getChangelogAddress("MCD_END"); }
    function esm()        public view returns (address) { return getChangelogAddress("MCD_ESM"); }
    function reg()        public view returns (address) { return getChangelogAddress("ILK_REGISTRY"); }
    function spotter()    public view returns (address) { return getChangelogAddress("MCD_SPOT"); }
    function flap()       public view returns (address) { return getChangelogAddress("MCD_FLAP"); }
    function flop()       public view returns (address) { return getChangelogAddress("MCD_FLOP"); }
    function osmMom()     public view returns (address) { return getChangelogAddress("OSM_MOM"); }
    function govGuard()   public view returns (address) { return getChangelogAddress("GOV_GUARD"); }
    function flipperMom() public view returns (address) { return getChangelogAddress("FLIPPER_MOM"); }
    function clipperMom() public view returns (address) { return getChangelogAddress("CLIPPER_MOM"); }
    function pauseProxy() public view returns (address) { return getChangelogAddress("MCD_PAUSE_PROXY"); }
    function autoLine()   public view returns (address) { return getChangelogAddress("MCD_IAM_AUTO_LINE"); }
    function daiJoin()    public view returns (address) { return getChangelogAddress("MCD_JOIN_DAI"); }
    function lerpFab()    public view returns (address) { return getChangelogAddress("LERP_FAB"); }

    function clip(bytes32 _ilk) public view returns (address _clip) {
        _clip = RegistryLike(reg()).xlip(_ilk);
    }

    function flip(bytes32 _ilk) public view returns (address _flip) {
        _flip = RegistryLike(reg()).xlip(_ilk);
    }

    function calc(bytes32 _ilk) public view returns (address _calc) {
        _calc = ClipLike(clip(_ilk)).calc();
    }

    function getChangelogAddress(bytes32 _key) public view returns (address) {
        return ChainlogLike_0(LOG).getAddress(_key);
    }

    /****************************/
    /*** Changelog Management ***/
    /****************************/
    /**
        @dev Set an address in the MCD on-chain changelog.
        @param _key Access key for the address (e.g. "MCD_VAT")
        @param _val The address associated with the _key
    */
    function setChangelogAddress(bytes32 _key, address _val) public {
        ChainlogLike_0(LOG).setAddress(_key, _val);
    }

    /**
        @dev Set version in the MCD on-chain changelog.
        @param _version Changelog version (e.g. "1.1.2")
    */
    function setChangelogVersion(string memory _version) public {
        ChainlogLike_0(LOG).setVersion(_version);
    }
    /**
        @dev Set IPFS hash of IPFS changelog in MCD on-chain changelog.
        @param _ipfsHash IPFS hash (e.g. "QmefQMseb3AiTapiAKKexdKHig8wroKuZbmLtPLv4u2YwW")
    */
    function setChangelogIPFS(string memory _ipfsHash) public {
        ChainlogLike_0(LOG).setIPFS(_ipfsHash);
    }
    /**
        @dev Set SHA256 hash in MCD on-chain changelog.
        @param _SHA256Sum SHA256 hash (e.g. "e42dc9d043a57705f3f097099e6b2de4230bca9a020c797508da079f9079e35b")
    */
    function setChangelogSHA256(string memory _SHA256Sum) public {
        ChainlogLike_0(LOG).setSha256sum(_SHA256Sum);
    }

    /**********************/
    /*** Authorizations ***/
    /**********************/
    /**
        @dev Give an address authorization to perform auth actions on the contract.
        @param _base   The address of the contract where the authorization will be set
        @param _ward   Address to be authorized
    */
    function authorize(address _base, address _ward) public {
        Authorizable(_base).rely(_ward);
    }
    /**
        @dev Revoke contract authorization from an address.
        @param _base   The address of the contract where the authorization will be revoked
        @param _ward   Address to be deauthorized
    */
    function deauthorize(address _base, address _ward) public {
        Authorizable(_base).deny(_ward);
    }
    /**
        @dev Give an address authorization to perform auth actions on the contract.
        @param _base   The address of the contract with a `setAuthority` pattern
        @param _authority   Address to be authorized
    */
    function setAuthority(address _base, address _authority) public {
        Authorizable(_base).setAuthority(_authority);
    }
    /**
        @dev Delegate vat authority to the specified address.
        @param _usr Address to be authorized
    */
    function delegateVat(address _usr) public {
        DssVat(vat()).hope(_usr);
    }
    /**
        @dev Revoke vat authority to the specified address.
        @param _usr Address to be deauthorized
    */
    function undelegateVat(address _usr) public {
        DssVat(vat()).nope(_usr);
    }

    /******************************/
    /*** OfficeHours Management ***/
    /******************************/

    /**
        @dev Returns true if a time is within office hours range
        @param _ts           The timestamp to check, usually block.timestamp
        @param _officeHours  true if office hours is enabled.
        @return              true if time is in castable range
    */
    function canCast(uint40 _ts, bool _officeHours) public pure returns (bool) {
        if (_officeHours) {
            uint256 day = (_ts / 1 days + 3) % 7;
            if (day >= 5)                 { return false; }  // Can only be cast on a weekday
            uint256 hour = _ts / 1 hours % 24;
            if (hour < 14 || hour >= 21)  { return false; }  // Outside office hours
        }
        return true;
    }

    /**
        @dev Calculate the next available cast time in epoch seconds
        @param _eta          The scheduled time of the spell plus the pause delay
        @param _ts           The current timestamp, usually block.timestamp
        @param _officeHours  true if office hours is enabled.
        @return castTime     The next available cast timestamp
    */
    function nextCastTime(uint40 _eta, uint40 _ts, bool _officeHours) public pure returns (uint256 castTime) {
        require(_eta != 0);  // "DssExecLib/invalid eta"
        require(_ts  != 0);  // "DssExecLib/invalid ts"
        castTime = _ts > _eta ? _ts : _eta; // Any day at XX:YY

        if (_officeHours) {
            uint256 day    = (castTime / 1 days + 3) % 7;
            uint256 hour   = castTime / 1 hours % 24;
            uint256 minute = castTime / 1 minutes % 60;
            uint256 second = castTime % 60;

            if (day >= 5) {
                castTime += (6 - day) * 1 days;                 // Go to Sunday XX:YY
                castTime += (24 - hour + 14) * 1 hours;         // Go to 14:YY UTC Monday
                castTime -= minute * 1 minutes + second;        // Go to 14:00 UTC
            } else {
                if (hour >= 21) {
                    if (day == 4) castTime += 2 days;           // If Friday, fast forward to Sunday XX:YY
                    castTime += (24 - hour + 14) * 1 hours;     // Go to 14:YY UTC next day
                    castTime -= minute * 1 minutes + second;    // Go to 14:00 UTC
                } else if (hour < 14) {
                    castTime += (14 - hour) * 1 hours;          // Go to 14:YY UTC same day
                    castTime -= minute * 1 minutes + second;    // Go to 14:00 UTC
                }
            }
        }
    }

    /**************************/
    /*** Accumulating Rates ***/
    /**************************/
    /**
        @dev Update rate accumulation for the Dai Savings Rate (DSR).
    */
    function accumulateDSR() public {
        Drippable(pot()).drip();
    }
    /**
        @dev Update rate accumulation for the stability fees of a given collateral type.
        @param _ilk   Collateral type
    */
    function accumulateCollateralStabilityFees(bytes32 _ilk) public {
        Drippable(jug()).drip(_ilk);
    }

    /*********************/
    /*** Price Updates ***/
    /*********************/
    /**
        @dev Update price of a given collateral type.
        @param _ilk   Collateral type
    */
    function updateCollateralPrice(bytes32 _ilk) public {
        Pricing(spotter()).poke(_ilk);
    }

    /****************************/
    /*** System Configuration ***/
    /****************************/
    /**
        @dev Set a contract in another contract, defining the relationship (ex. set a new Calc contract in Clip)
        @param _base   The address of the contract where the new contract address will be filed
        @param _what   Name of contract to file
        @param _addr   Address of contract to file
    */
    function setContract(address _base, bytes32 _what, address _addr) public {
        Fileable(_base).file(_what, _addr);
    }
    /**
        @dev Set a contract in another contract, defining the relationship (ex. set a new Calc contract in a Clip)
        @param _base   The address of the contract where the new contract address will be filed
        @param _ilk    Collateral type
        @param _what   Name of contract to file
        @param _addr   Address of contract to file
    */
    function setContract(address _base, bytes32 _ilk, bytes32 _what, address _addr) public {
        Fileable(_base).file(_ilk, _what, _addr);
    }
    /**
        @dev Set a value in a contract, via a governance authorized File pattern.
        @param _base   The address of the contract where the new contract address will be filed
        @param _what   Name of tag for the value (e.x. "Line")
        @param _amt    The value to set or update
    */
    function setValue(address _base, bytes32 _what, uint256 _amt) public {
        Fileable(_base).file(_what, _amt);
    }
    /**
        @dev Set an ilk-specific value in a contract, via a governance authorized File pattern.
        @param _base   The address of the contract where the new value will be filed
        @param _ilk    Collateral type
        @param _what   Name of tag for the value (e.x. "Line")
        @param _amt    The value to set or update
    */
    function setValue(address _base, bytes32 _ilk, bytes32 _what, uint256 _amt) public {
        Fileable(_base).file(_ilk, _what, _amt);
    }

    /******************************/
    /*** System Risk Parameters ***/
    /******************************/
    // function setGlobalDebtCeiling(uint256 _amount) public { setGlobalDebtCeiling(vat(), _amount); }
    /**
        @dev Set the global debt ceiling. Amount will be converted to the correct internal precision.
        @param _amount The amount to set in DAI (ex. 10m DAI amount == 10000000)
    */
    function setGlobalDebtCeiling(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-global-Line-precision"
        setValue(vat(), "Line", _amount * RAD);
    }
    /**
        @dev Increase the global debt ceiling by a specific amount. Amount will be converted to the correct internal precision.
        @param _amount The amount to add in DAI (ex. 10m DAI amount == 10000000)
    */
    function increaseGlobalDebtCeiling(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-Line-increase-precision"
        address _vat = vat();
        setValue(_vat, "Line", DssVat(_vat).Line() + _amount * RAD);
    }
    /**
        @dev Decrease the global debt ceiling by a specific amount. Amount will be converted to the correct internal precision.
        @param _amount The amount to reduce in DAI (ex. 10m DAI amount == 10000000)
    */
    function decreaseGlobalDebtCeiling(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-Line-decrease-precision"
        address _vat = vat();
        setValue(_vat, "Line", DssVat(_vat).Line() - _amount * RAD);
    }
    /**
        @dev Set the Dai Savings Rate. See: docs/rates.txt
        @param _rate   The accumulated rate (ex. 4% => 1000000001243680656318820312)
        @param _doDrip `true` to accumulate interest owed
    */
    function setDSR(uint256 _rate, bool _doDrip) public {
        require((_rate >= RAY) && (_rate <= RATES_ONE_HUNDRED_PCT));  // "LibDssExec/dsr-out-of-bounds"
        if (_doDrip) Drippable(pot()).drip();
        setValue(pot(), "dsr", _rate);
    }
    /**
        @dev Set the DAI amount for system surplus auctions. Amount will be converted to the correct internal precision.
        @param _amount The amount to set in DAI (ex. 10m DAI amount == 10000000)
    */
    function setSurplusAuctionAmount(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-vow-bump-precision"
        setValue(vow(), "bump", _amount * RAD);
    }
    /**
        @dev Set the DAI amount for system surplus buffer, must be exceeded before surplus auctions start. Amount will be converted to the correct internal precision.
        @param _amount The amount to set in DAI (ex. 10m DAI amount == 10000000)
    */
    function setSurplusBuffer(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-vow-hump-precision"
        setValue(vow(), "hump", _amount * RAD);
    }
    /**
        @dev Set minimum bid increase for surplus auctions. Amount will be converted to the correct internal precision.
        @dev Equation used for conversion is (1 + pct / 10,000) * WAD
        @param _pct_bps The pct, in basis points, to set in integer form (x100). (ex. 5% = 5 * 100 = 500)
    */
    function setMinSurplusAuctionBidIncrease(uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT);  // "LibDssExec/incorrect-flap-beg-precision"
        setValue(flap(), "beg", WAD + wdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }
    /**
        @dev Set bid duration for surplus auctions.
        @param _duration Amount of time for bids. (in seconds)
    */
    function setSurplusAuctionBidDuration(uint256 _duration) public {
        setValue(flap(), "ttl", _duration);
    }
    /**
        @dev Set total auction duration for surplus auctions.
        @param _duration Amount of time for auctions. (in seconds)
    */
    function setSurplusAuctionDuration(uint256 _duration) public {
        setValue(flap(), "tau", _duration);
    }
    /**
        @dev Set the number of seconds that pass before system debt is auctioned for MKR tokens.
        @param _duration Duration in seconds
    */
    function setDebtAuctionDelay(uint256 _duration) public {
        setValue(vow(), "wait", _duration);
    }
    /**
        @dev Set the DAI amount for system debt to be covered by each debt auction. Amount will be converted to the correct internal precision.
        @param _amount The amount to set in DAI (ex. 10m DAI amount == 10000000)
    */
    function setDebtAuctionDAIAmount(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-vow-sump-precision"
        setValue(vow(), "sump", _amount * RAD);
    }
    /**
        @dev Set the starting MKR amount to be auctioned off to cover system debt in debt auctions. Amount will be converted to the correct internal precision.
        @param _amount The amount to set in MKR (ex. 250 MKR amount == 250)
    */
    function setDebtAuctionMKRAmount(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-vow-dump-precision"
        setValue(vow(), "dump", _amount * WAD);
    }
    /**
        @dev Set minimum bid increase for debt auctions. Amount will be converted to the correct internal precision.
        @dev Equation used for conversion is (1 + pct / 10,000) * WAD
        @param _pct_bps    The pct, in basis points, to set in integer form (x100). (ex. 5% = 5 * 100 = 500)
    */
    function setMinDebtAuctionBidIncrease(uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT);  // "LibDssExec/incorrect-flop-beg-precision"
        setValue(flop(), "beg", WAD + wdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }
    /**
        @dev Set bid duration for debt auctions.
        @param _duration Amount of time for bids. (seconds)
    */
    function setDebtAuctionBidDuration(uint256 _duration) public {
        require(_duration < type(uint48).max);  // "LibDssExec/incorrect-flop-ttl-precision"
        setValue(flop(), "ttl", _duration);
    }
    /**
        @dev Set total auction duration for debt auctions.
        @param _duration Amount of time for auctions. (seconds)
    */
    function setDebtAuctionDuration(uint256 _duration) public {
        require(_duration < type(uint48).max);  // "LibDssExec/incorrect-flop-tau-precision"
        setValue(flop(), "tau", _duration);
    }
    /**
        @dev Set the rate of increasing amount of MKR out for auction during debt auctions. Amount will be converted to the correct internal precision.
        @dev MKR amount is increased by this rate every "tick" (if auction duration has passed and no one has bid on the MKR)
        @dev Equation used for conversion is (1 + pct / 10,000) * WAD
        @param _pct_bps    The pct, in basis points, to set in integer form (x100). (ex. 5% = 5 * 100 = 500)
    */
    function setDebtAuctionMKRIncreaseRate(uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT);  // "LibDssExec/incorrect-flop-pad-precision"
        setValue(flop(), "pad", WAD + wdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }
    /**
        @dev Set the maximum total DAI amount that can be out for liquidation in the system at any point. Amount will be converted to the correct internal precision.
        @param _amount The amount to set in DAI (ex. 250,000 DAI amount == 250000)
    */
    function setMaxTotalDAILiquidationAmount(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-dog-Hole-precision"
        setValue(dog(), "Hole", _amount * RAD);
    }
    /**
        @dev (LIQ 1.2) Set the maximum total DAI amount that can be out for liquidation in the system at any point. Amount will be converted to the correct internal precision.
        @param _amount The amount to set in DAI (ex. 250,000 DAI amount == 250000)
    */
    function setMaxTotalDAILiquidationAmountLEGACY(uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-cat-box-amount"
        setValue(cat(), "box", _amount * RAD);
    }
    /**
        @dev Set the duration of time that has to pass during emergency shutdown before collateral can start being claimed by DAI holders.
        @param _duration Time in seconds to set for ES processing time
    */
    function setEmergencyShutdownProcessingTime(uint256 _duration) public {
        setValue(end(), "wait", _duration);
    }
    /**
        @dev Set the global stability fee (is not typically used, currently is 0).
            Many of the settings that change weekly rely on the rate accumulator
            described at https://docs.makerdao.com/smart-contract-modules/rates-module
            To check this yourself, use the following rate calculation (example 8%):

            $ bc -l <<< 'scale=27; e( l(1.08)/(60 * 60 * 24 * 365) )'

            A table of rates can also be found at:
            https://ipfs.io/ipfs/QmefQMseb3AiTapiAKKexdKHig8wroKuZbmLtPLv4u2YwW
        @param _rate   The accumulated rate (ex. 4% => 1000000001243680656318820312)
    */
    function setGlobalStabilityFee(uint256 _rate) public {
        require((_rate >= RAY) && (_rate <= RATES_ONE_HUNDRED_PCT));  // "LibDssExec/global-stability-fee-out-of-bounds"
        setValue(jug(), "base", _rate);
    }
    /**
        @dev Set the value of DAI in the reference asset (e.g. $1 per DAI). Value will be converted to the correct internal precision.
        @dev Equation used for conversion is value * RAY / 1000
        @param _value The value to set as integer (x1000) (ex. $1.025 == 1025)
    */
    function setDAIReferenceValue(uint256 _value) public {
        require(_value < WAD);  // "LibDssExec/incorrect-par-precision"
        setValue(spotter(), "par", rdiv(_value, 1000));
    }

    /*****************************/
    /*** Collateral Management ***/
    /*****************************/
    /**
        @dev Set a collateral debt ceiling. Amount will be converted to the correct internal precision.
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The amount to set in DAI (ex. 10m DAI amount == 10000000)
    */
    function setIlkDebtCeiling(bytes32 _ilk, uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-ilk-line-precision"
        setValue(vat(), _ilk, "line", _amount * RAD);
    }
    /**
        @dev Increase a collateral debt ceiling. Amount will be converted to the correct internal precision.
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The amount to increase in DAI (ex. 10m DAI amount == 10000000)
        @param _global If true, increases the global debt ceiling by _amount
    */
    function increaseIlkDebtCeiling(bytes32 _ilk, uint256 _amount, bool _global) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-ilk-line-precision"
        address _vat = vat();
        (,,,uint256 line_,) = DssVat(_vat).ilks(_ilk);
        setValue(_vat, _ilk, "line", line_ + _amount * RAD);
        if (_global) { increaseGlobalDebtCeiling(_amount); }
    }
    /**
        @dev Decrease a collateral debt ceiling. Amount will be converted to the correct internal precision.
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The amount to decrease in DAI (ex. 10m DAI amount == 10000000)
        @param _global If true, decreases the global debt ceiling by _amount
    */
    function decreaseIlkDebtCeiling(bytes32 _ilk, uint256 _amount, bool _global) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-ilk-line-precision"
        address _vat = vat();
        (,,,uint256 line_,) = DssVat(_vat).ilks(_ilk);
        setValue(_vat, _ilk, "line", line_ - _amount * RAD);
        if (_global) { decreaseGlobalDebtCeiling(_amount); }
    }
    /**
        @dev Set a RWA collateral debt ceiling by specifying its new oracle price.
        @param _ilk      The ilk to update (ex. bytes32("ETH-A"))
        @param _ceiling  The new debt ceiling in natural units (e.g. set 10m DAI as 10_000_000)
        @param _price    The new oracle price in natural units
        @dev note: _price should enable DAI to be drawn over the loan period while taking into
                   account the configured ink amount, interest rate and liquidation ratio
        @dev note: _price * WAD should be greater than or equal to the current oracle price
    */
    function setRWAIlkDebtCeiling(bytes32 _ilk, uint256 _ceiling, uint256 _price) public {
        require(_price < WAD);
        setIlkDebtCeiling(_ilk, _ceiling);
        RwaOracleLike(getChangelogAddress("MIP21_LIQUIDATION_ORACLE")).bump(_ilk, _price * WAD);
        updateCollateralPrice(_ilk);
    }
    /**
        @dev Set the parameters for an ilk in the "MCD_IAM_AUTO_LINE" auto-line
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The Maximum value (ex. 100m DAI amount == 100000000)
        @param _gap    The amount of Dai per step (ex. 5m Dai == 5000000)
        @param _ttl    The amount of time (in seconds)
    */
    function setIlkAutoLineParameters(bytes32 _ilk, uint256 _amount, uint256 _gap, uint256 _ttl) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-auto-line-amount-precision"
        require(_gap < WAD);  // "LibDssExec/incorrect-auto-line-gap-precision"
        IAMLike(autoLine()).setIlk(_ilk, _amount * RAD, _gap * RAD, _ttl);
    }
    /**
        @dev Set the debt ceiling for an ilk in the "MCD_IAM_AUTO_LINE" auto-line without updating the time values
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The Maximum value (ex. 100m DAI amount == 100000000)
    */
    function setIlkAutoLineDebtCeiling(bytes32 _ilk, uint256 _amount) public {
        address _autoLine = autoLine();
        (, uint256 gap, uint48 ttl,,) = IAMLike(_autoLine).ilks(_ilk);
        require(gap != 0 && ttl != 0);  // "LibDssExec/auto-line-not-configured"
        IAMLike(_autoLine).setIlk(_ilk, _amount * RAD, uint256(gap), uint256(ttl));
    }
    /**
        @dev Remove an ilk in the "MCD_IAM_AUTO_LINE" auto-line
        @param _ilk    The ilk to remove (ex. bytes32("ETH-A"))
    */
    function removeIlkFromAutoLine(bytes32 _ilk) public {
        IAMLike(autoLine()).remIlk(_ilk);
    }
    /**
        @dev Set a collateral minimum vault amount. Amount will be converted to the correct internal precision.
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The amount to set in DAI (ex. 10m DAI amount == 10000000)
    */
    function setIlkMinVaultAmount(bytes32 _ilk, uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-ilk-dust-precision"
        (,, uint256 _hole,) = DogLike(dog()).ilks(_ilk);
        require(_amount <= _hole / RAD);  // Ensure ilk.hole >= dust
        setValue(vat(), _ilk, "dust", _amount * RAD);
        (bool ok,) = clip(_ilk).call(abi.encodeWithSignature("upchost()")); ok;
    }
    /**
        @dev Set a collateral liquidation penalty. Amount will be converted to the correct internal precision.
        @dev Equation used for conversion is (1 + pct / 10,000) * WAD
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _pct_bps    The pct, in basis points, to set in integer form (x100). (ex. 10.25% = 10.25 * 100 = 1025)
    */
    function setIlkLiquidationPenalty(bytes32 _ilk, uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT);  // "LibDssExec/incorrect-ilk-chop-precision"
        setValue(dog(), _ilk, "chop", WAD + wdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
        (bool ok,) = clip(_ilk).call(abi.encodeWithSignature("upchost()")); ok;
    }
    /**
        @dev Set max DAI amount for liquidation per vault for collateral. Amount will be converted to the correct internal precision.
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The amount to set in DAI (ex. 10m DAI amount == 10000000)
    */
    function setIlkMaxLiquidationAmount(bytes32 _ilk, uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-ilk-hole-precision"
        setValue(dog(), _ilk, "hole", _amount * RAD);
    }
    /**
        @dev Set a collateral liquidation ratio. Amount will be converted to the correct internal precision.
        @dev Equation used for conversion is pct * RAY / 10,000
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _pct_bps    The pct, in basis points, to set in integer form (x100). (ex. 150% = 150 * 100 = 15000)
    */
    function setIlkLiquidationRatio(bytes32 _ilk, uint256 _pct_bps) public {
        require(_pct_bps < 10 * BPS_ONE_HUNDRED_PCT); // "LibDssExec/incorrect-ilk-mat-precision" // Fails if pct >= 1000%
        require(_pct_bps >= BPS_ONE_HUNDRED_PCT); // the liquidation ratio has to be bigger or equal to 100%
        setValue(spotter(), _ilk, "mat", rdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }
    /**
        @dev Set an auction starting multiplier. Amount will be converted to the correct internal precision.
        @dev Equation used for conversion is pct * RAY / 10,000
        @param _ilk      The ilk to update (ex. bytes32("ETH-A"))
        @param _pct_bps  The pct, in basis points, to set in integer form (x100). (ex. 1.3x starting multiplier = 130% = 13000)
    */
    function setStartingPriceMultiplicativeFactor(bytes32 _ilk, uint256 _pct_bps) public {
        require(_pct_bps < 10 * BPS_ONE_HUNDRED_PCT); // "LibDssExec/incorrect-ilk-mat-precision" // Fails if gt 10x
        require(_pct_bps >= BPS_ONE_HUNDRED_PCT); // fail if start price is less than OSM price
        setValue(clip(_ilk), "buf", rdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }

    /**
        @dev Set the amout of time before an auction resets.
        @param _ilk      The ilk to update (ex. bytes32("ETH-A"))
        @param _duration Amount of time before auction resets (in seconds).
    */
    function setAuctionTimeBeforeReset(bytes32 _ilk, uint256 _duration) public {
        setValue(clip(_ilk), "tail", _duration);
    }

    /**
        @dev Percentage drop permitted before auction reset
        @param _ilk     The ilk to update (ex. bytes32("ETH-A"))
        @param _pct_bps The pct, in basis points, of drop to permit (x100).
    */
    function setAuctionPermittedDrop(bytes32 _ilk, uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT); // "LibDssExec/incorrect-clip-cusp-value"
        setValue(clip(_ilk), "cusp", rdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }

    /**
        @dev Percentage of tab to suck from vow to incentivize keepers. Amount will be converted to the correct internal precision.
        @param _ilk     The ilk to update (ex. bytes32("ETH-A"))
        @param _pct_bps The pct, in basis points, of the tab to suck. (0.01% == 1)
    */
    function setKeeperIncentivePercent(bytes32 _ilk, uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT); // "LibDssExec/incorrect-clip-chip-precision"
        setValue(clip(_ilk), "chip", wdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }

    /**
        @dev Set max DAI amount for flat rate keeper incentive. Amount will be converted to the correct internal precision.
        @param _ilk    The ilk to update (ex. bytes32("ETH-A"))
        @param _amount The amount to set in DAI (ex. 1000 DAI amount == 1000)
    */
    function setKeeperIncentiveFlatRate(bytes32 _ilk, uint256 _amount) public {
        require(_amount < WAD); // "LibDssExec/incorrect-clip-tip-precision"
        setValue(clip(_ilk), "tip", _amount * RAD);
    }

    /**
        @dev Sets the circuit breaker price tolerance in the clipper mom.
            This is somewhat counter-intuitive,
             to accept a 25% price drop, use a value of 75%
        @param _clip    The clipper to set the tolerance for
        @param _pct_bps The pct, in basis points, to set in integer form (x100). (ex. 5% = 5 * 100 = 500)
    */
    function setLiquidationBreakerPriceTolerance(address _clip, uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT);  // "LibDssExec/incorrect-clippermom-price-tolerance"
        MomLike(clipperMom()).setPriceTolerance(_clip, rdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }

    /**
        @dev Set the stability fee for a given ilk.
            Many of the settings that change weekly rely on the rate accumulator
            described at https://docs.makerdao.com/smart-contract-modules/rates-module
            To check this yourself, use the following rate calculation (example 8%):

            $ bc -l <<< 'scale=27; e( l(1.08)/(60 * 60 * 24 * 365) )'

            A table of rates can also be found at:
            https://ipfs.io/ipfs/QmefQMseb3AiTapiAKKexdKHig8wroKuZbmLtPLv4u2YwW

        @param _ilk    The ilk to update (ex. bytes32("ETH-A") )
        @param _rate   The accumulated rate (ex. 4% => 1000000001243680656318820312)
        @param _doDrip `true` to accumulate stability fees for the collateral
    */
    function setIlkStabilityFee(bytes32 _ilk, uint256 _rate, bool _doDrip) public {
        require((_rate >= RAY) && (_rate <= RATES_ONE_HUNDRED_PCT));  // "LibDssExec/ilk-stability-fee-out-of-bounds"
        address _jug = jug();
        if (_doDrip) Drippable(_jug).drip(_ilk);

        setValue(_jug, _ilk, "duty", _rate);
    }

    /*************************/
    /*** Abacus Management ***/
    /*************************/

    /**
        @dev Set the number of seconds from the start when the auction reaches zero price.
        @dev Abacus:LinearDecrease only.
        @param _calc     The address of the LinearDecrease pricing contract
        @param _duration Amount of time for auctions.
    */
    function setLinearDecrease(address _calc, uint256 _duration) public {
        setValue(_calc, "tau", _duration);
    }

    /**
        @dev Set the number of seconds for each price step.
        @dev Abacus:StairstepExponentialDecrease only.
        @param _calc     The address of the StairstepExponentialDecrease pricing contract
        @param _duration Length of time between price drops [seconds]
        @param _pct_bps Per-step multiplicative factor in basis points. (ex. 99% == 9900)
    */
    function setStairstepExponentialDecrease(address _calc, uint256 _duration, uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT); // DssExecLib/cut-too-high
        setValue(_calc, "cut", rdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
        setValue(_calc, "step", _duration);
    }
    /**
        @dev Set the number of seconds for each price step. (99% cut = 1% price drop per step)
             Amounts will be converted to the correct internal precision.
        @dev Abacus:ExponentialDecrease only
        @param _calc     The address of the ExponentialDecrease pricing contract
        @param _pct_bps Per-step multiplicative factor in basis points. (ex. 99% == 9900)
    */
    function setExponentialDecrease(address _calc, uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT); // DssExecLib/cut-too-high
        setValue(_calc, "cut", rdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }

    /*************************/
    /*** Oracle Management ***/
    /*************************/
    /**
        @dev Allows an oracle to read prices from its source feeds
        @param _oracle  An OSM or LP oracle contract
    */
    function whitelistOracleMedians(address _oracle) public {
        (bool ok, bytes memory data) = _oracle.call(abi.encodeWithSignature("orb0()"));
        if (ok) {
            // Token is an LP oracle
            address median0 = abi.decode(data, (address));
            addReaderToWhitelistCall(median0, _oracle);
            addReaderToWhitelistCall(OracleLike_0(_oracle).orb1(), _oracle);
        } else {
            // Standard OSM
            addReaderToWhitelistCall(OracleLike_0(_oracle).src(), _oracle);
        }
    }
    /**
        @dev Adds an address to the OSM or Median's reader whitelist, allowing the address to read prices.
        @param _oracle        Oracle Security Module (OSM) or Median core contract address
        @param _reader     Address to add to whitelist
    */
    function addReaderToWhitelist(address _oracle, address _reader) public {
        OracleLike_0(_oracle).kiss(_reader);
    }
    /**
        @dev Removes an address to the OSM or Median's reader whitelist, disallowing the address to read prices.
        @param _oracle     Oracle Security Module (OSM) or Median core contract address
        @param _reader     Address to remove from whitelist
    */
    function removeReaderFromWhitelist(address _oracle, address _reader) public {
        OracleLike_0(_oracle).diss(_reader);
    }
    /**
        @dev Adds an address to the OSM or Median's reader whitelist, allowing the address to read prices.
        @param _oracle  OSM or Median core contract address
        @param _reader  Address to add to whitelist
    */
    function addReaderToWhitelistCall(address _oracle, address _reader) public {
        (bool ok,) = _oracle.call(abi.encodeWithSignature("kiss(address)", _reader)); ok;
    }
    /**
        @dev Removes an address to the OSM or Median's reader whitelist, disallowing the address to read prices.
        @param _oracle  Oracle Security Module (OSM) or Median core contract address
        @param _reader  Address to remove from whitelist
    */
    function removeReaderFromWhitelistCall(address _oracle, address _reader) public {
        (bool ok,) = _oracle.call(abi.encodeWithSignature("diss(address)", _reader)); ok;
    }
    /**
        @dev Sets the minimum number of valid messages from whitelisted oracle feeds needed to update median price.
        @param _median     Median core contract address
        @param _minQuorum  Minimum number of valid messages from whitelisted oracle feeds needed to update median price (NOTE: MUST BE ODD NUMBER)
    */
    function setMedianWritersQuorum(address _median, uint256 _minQuorum) public {
        OracleLike_0(_median).setBar(_minQuorum);
    }
    /**
        @dev Add OSM address to OSM mom, allowing it to be frozen by governance.
        @param _osm        Oracle Security Module (OSM) core contract address
        @param _ilk        Collateral type using OSM
    */
    function allowOSMFreeze(address _osm, bytes32 _ilk) public {
        MomLike(osmMom()).setOsm(_ilk, _osm);
    }

    /*****************************/
    /*** Direct Deposit Module ***/
    /*****************************/

    /**
        @dev Sets the target rate threshold for a dai direct deposit module (d3m)
        @dev Aave: Targets the variable borrow rate
        @param _d3m     The address of the D3M contract
        @param _pct_bps Target rate in basis points. (ex. 4% == 400)
    */
    function setD3MTargetInterestRate(address _d3m, uint256 _pct_bps) public {
        require(_pct_bps < BPS_ONE_HUNDRED_PCT); // DssExecLib/bar-too-high
        setValue(_d3m, "bar", rdiv(_pct_bps, BPS_ONE_HUNDRED_PCT));
    }

    /*****************************/
    /*** Collateral Onboarding ***/
    /*****************************/

    /**
        @dev Performs basic functions and sanity checks to add a new collateral type to the MCD system
        @param _ilk      Collateral type key code [Ex. "ETH-A"]
        @param _gem      Address of token contract
        @param _join     Address of join adapter
        @param _clip     Address of liquidation agent
        @param _calc     Address of the pricing function
        @param _pip      Address of price feed
    */
    function addCollateralBase(
        bytes32 _ilk,
        address _gem,
        address _join,
        address _clip,
        address _calc,
        address _pip
    ) public {
        // Sanity checks
        address _vat = vat();
        address _dog = dog();
        address _spotter = spotter();
        require(JoinLike(_join).vat() == _vat);     // "join-vat-not-match"
        require(JoinLike(_join).ilk() == _ilk);     // "join-ilk-not-match"
        require(JoinLike(_join).gem() == _gem);     // "join-gem-not-match"
        require(JoinLike(_join).dec() ==
                   ERC20(_gem).decimals());         // "join-dec-not-match"
        require(ClipLike(_clip).vat() == _vat);     // "clip-vat-not-match"
        require(ClipLike(_clip).dog() == _dog);     // "clip-dog-not-match"
        require(ClipLike(_clip).ilk() == _ilk);     // "clip-ilk-not-match"
        require(ClipLike(_clip).spotter() == _spotter);  // "clip-ilk-not-match"

        // Set the token PIP in the Spotter
        setContract(spotter(), _ilk, "pip", _pip);

        // Set the ilk Clipper in the Dog
        setContract(_dog, _ilk, "clip", _clip);
        // Set vow in the clip
        setContract(_clip, "vow", vow());
        // Set the pricing function for the Clipper
        setContract(_clip, "calc", _calc);

        // Init ilk in Vat & Jug
        Initializable(_vat).init(_ilk);  // Vat
        Initializable(jug()).init(_ilk);  // Jug

        // Allow ilk Join to modify Vat registry
        authorize(_vat, _join);
        // Allow ilk Join to suck dai for keepers
        authorize(_vat, _clip);
        // Allow the ilk Clipper to reduce the Dog hole on deal()
        authorize(_dog, _clip);
        // Allow Dog to kick auctions in ilk Clipper
        authorize(_clip, _dog);
        // Allow End to yank auctions in ilk Clipper
        authorize(_clip, end());
        // Authorize the ESM to execute in the clipper
        authorize(_clip, esm());

        // Add new ilk to the IlkRegistry
        RegistryLike(reg()).add(_join);
    }

    // Complete collateral onboarding logic.
    function addNewCollateral(CollateralOpts memory co) public {
        // Add the collateral to the system.
        addCollateralBase(co.ilk, co.gem, co.join, co.clip, co.calc, co.pip);
        address clipperMom_ = clipperMom();

        if (!co.isLiquidatable) {
            // Disallow Dog to kick auctions in ilk Clipper
            setValue(co.clip, "stopped", 3);
        } else {
            // Grant ClipperMom access to the ilk Clipper
            authorize(co.clip, clipperMom_);
        }

        if(co.isOSM) { // If pip == OSM
            // Allow OsmMom to access to the TOKEN OSM
            authorize(co.pip, osmMom());
            if (co.whitelistOSM) { // If median is src in OSM
                // Whitelist OSM to read the Median data (only necessary if it is the first time the token is being added to an ilk)
                whitelistOracleMedians(co.pip);
            }
            // Whitelist Spotter to read the OSM data (only necessary if it is the first time the token is being added to an ilk)
            addReaderToWhitelist(co.pip, spotter());
            // Whitelist Clipper on pip
            addReaderToWhitelist(co.pip, co.clip);
            // Allow the clippermom to access the feed
            addReaderToWhitelist(co.pip, clipperMom_);
            // Whitelist End to read the OSM data (only necessary if it is the first time the token is being added to an ilk)
            addReaderToWhitelist(co.pip, end());
            // Set TOKEN OSM in the OsmMom for new ilk
            allowOSMFreeze(co.pip, co.ilk);
        }
        // Increase the global debt ceiling by the ilk ceiling
        increaseGlobalDebtCeiling(co.ilkDebtCeiling);

        // Set the ilk debt ceiling
        setIlkDebtCeiling(co.ilk, co.ilkDebtCeiling);

        // Set the hole size
        setIlkMaxLiquidationAmount(co.ilk, co.maxLiquidationAmount);

        // Set the ilk dust
        setIlkMinVaultAmount(co.ilk, co.minVaultAmount);

        // Set the ilk liquidation penalty
        setIlkLiquidationPenalty(co.ilk, co.liquidationPenalty);

        // Set the ilk stability fee
        setIlkStabilityFee(co.ilk, co.ilkStabilityFee, true);

        // Set the auction starting price multiplier
        setStartingPriceMultiplicativeFactor(co.ilk, co.startingPriceFactor);

        // Set the amount of time before an auction resets.
        setAuctionTimeBeforeReset(co.ilk, co.auctionDuration);

        // Set the allowed auction drop percentage before reset
        setAuctionPermittedDrop(co.ilk, co.permittedDrop);

        // Set the ilk min collateralization ratio
        setIlkLiquidationRatio(co.ilk, co.liquidationRatio);

        // Set the price tolerance in the liquidation circuit breaker
        setLiquidationBreakerPriceTolerance(co.clip, co.breakerTolerance);

        // Set a flat rate for the keeper reward
        setKeeperIncentiveFlatRate(co.ilk, co.kprFlatReward);

        // Set the percentage of liquidation as keeper award
        setKeeperIncentivePercent(co.ilk, co.kprPctReward);

        // Update ilk spot value in Vat
        updateCollateralPrice(co.ilk);
    }

    /***************/
    /*** Payment ***/
    /***************/
    /**
        @dev Send a payment in ERC20 DAI from the surplus buffer.
        @param _target The target address to send the DAI to.
        @param _amount The amount to send in DAI (ex. 10m DAI amount == 10000000)
    */
    function sendPaymentFromSurplusBuffer(address _target, uint256 _amount) public {
        require(_amount < WAD);  // "LibDssExec/incorrect-ilk-line-precision"
        DssVat(vat()).suck(vow(), address(this), _amount * RAD);
        JoinLike(daiJoin()).exit(_target, _amount * WAD);
    }

    /************/
    /*** Misc ***/
    /************/
    /**
        @dev Initiate linear interpolation on an administrative value over time.
        @param _name        The label for this lerp instance
        @param _target      The target contract
        @param _what        The target parameter to adjust
        @param _startTime   The time for this lerp
        @param _start       The start value for the target parameter
        @param _end         The end value for the target parameter
        @param _duration    The duration of the interpolation
    */
    function linearInterpolation(bytes32 _name, address _target, bytes32 _what, uint256 _startTime, uint256 _start, uint256 _end, uint256 _duration) public returns (address) {
        address lerp = LerpFactoryLike(lerpFab()).newLerp(_name, _target, _what, _startTime, _start, _end, _duration);
        Authorizable(_target).rely(lerp);
        LerpLike(lerp).tick();
        return lerp;
    }
    /**
        @dev Initiate linear interpolation on an administrative value over time.
        @param _name        The label for this lerp instance
        @param _target      The target contract
        @param _ilk         The ilk to target
        @param _what        The target parameter to adjust
        @param _startTime   The time for this lerp
        @param _start       The start value for the target parameter
        @param _end         The end value for the target parameter
        @param _duration    The duration of the interpolation
    */
    function linearInterpolation(bytes32 _name, address _target, bytes32 _ilk, bytes32 _what, uint256 _startTime, uint256 _start, uint256 _end, uint256 _duration) public returns (address) {
        address lerp = LerpFactoryLike(lerpFab()).newIlkLerp(_name, _target, _ilk, _what, _startTime, _start, _end, _duration);
        Authorizable(_target).rely(lerp);
        LerpLike(lerp).tick();
        return lerp;
    }
}

// lib/dss-exec-lib/src/DssAction.sol

//
// DssAction.sol -- DSS Executive Spell Actions
//
// Copyright (C) 2020-2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

interface OracleLike_1 {
    function src() external view returns (address);
}

abstract contract DssAction {

    using DssExecLib for *;

    // Modifier used to limit execution time when office hours is enabled
    modifier limited {
        require(DssExecLib.canCast(uint40(block.timestamp), officeHours()), "Outside office hours");
        _;
    }

    // Office Hours defaults to true by default.
    //   To disable office hours, override this function and
    //    return false in the inherited action.
    function officeHours() public view virtual returns (bool) {
        return true;
    }

    // DssExec calls execute. We limit this function subject to officeHours modifier.
    function execute() external limited {
        actions();
    }

    // DssAction developer must override `actions()` and place all actions to be called inside.
    //   The DssExec function will call this subject to the officeHours limiter
    //   By keeping this function public we allow simulations of `execute()` on the actions outside of the cast time.
    function actions() public virtual;

    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: seth keccak -- "$(wget https://<executive-vote-canonical-post> -q -O - 2>/dev/null)"
    function description() external view virtual returns (string memory);

    // Returns the next available cast time
    function nextCastTime(uint256 eta) external view returns (uint256 castTime) {
        require(eta <= type(uint40).max);
        castTime = DssExecLib.nextCastTime(uint40(eta), uint40(block.timestamp), officeHours());
    }
}

// src/dependencies/endgame-toolkit/treasury-funded-farms/TreasuryFundedFarmingInit.sol

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

struct FarmingInitParams {
    address stakingToken;
    address rewardsToken;
    address rewards;
    bytes32 rewardsKey; // Chainlog key
    address dist;
    bytes32 distKey; // Chainlog key
    address distJob;
    uint256 distJobInterval; // in seconds
    address vest;
    uint256 vestTot; // wad
    uint256 vestBgn; // unix timestamp
    uint256 vestTau; // in seconds
}

struct FarmingInitResult {
    uint256 vestId;
    uint256 distributedAmount;
}

struct FarmingUpdateVestParams {
    address dist;
    uint256 vestTot;
    uint256 vestBgn;
    uint256 vestTau;
}

struct FarmingUpdateVestResult {
    uint256 prevVestId;
    uint256 prevDistributedAmount;
    uint256 vestId;
    uint256 distributedAmount;
}

library TreasuryFundedFarmingInit {
    ChainlogLike_1 internal constant chainlog = ChainlogLike_1(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    function initFarm(FarmingInitParams memory p) internal returns (FarmingInitResult memory r) {
        DssVestTransferrableLike vest = DssVestTransferrableLike(p.vest);
        // Note: `p.vest` is expected to be of type `DssVestTransferrable`
        require(vest.czar() == address(this), "initFarm/vest-czar-mismatch");
        require(vest.gem() == p.rewardsToken, "initFarm/vest-gem-mismatch");

        StakingRewardsLike_1 rewards = StakingRewardsLike_1(p.rewards);
        require(rewards.stakingToken() == p.stakingToken, "initFarm/rewards-staking-token-mismatch");
        require(rewards.rewardsToken() == p.rewardsToken, "initFarm/rewards-rewards-token-mismatch");
        require(rewards.rewardRate() == 0, "initFarm/reward-rate-not-zero");
        require(rewards.rewardsDistribution() == address(0), "initFarm/rewards-distribution-already-set");
        require(rewards.owner() == address(this), "initFarm/invalid-owner");

        VestedRewardsDistributionLike_1 dist = VestedRewardsDistributionLike_1(p.dist);
        require(dist.gem() == p.rewardsToken, "initFarm/dist-gem-mismatch");
        require(dist.dssVest() == p.vest, "initFarm/dist-dss-vest-mismatch");
        require(dist.vestId() == 0, "initFarm/dist-vest-id-already-set");
        require(dist.stakingRewards() == p.rewards, "initFarm/dist-staking-rewards-mismatch");

        // Set `dist` with `rewardsDistribution` role in `rewards`.
        StakingRewardsInit.init(p.rewards, StakingRewardsInitParams({dist: p.dist}));

        ERC20Like rewardsToken = ERC20Like(p.rewardsToken);
        // Increase `rewardsToken` `p.vest` allowance from the treasury for `p.vestTot`.
        uint256 allowance = rewardsToken.allowance(address(this), p.vest);
        rewardsToken.approve(p.vest, allowance + p.vestTot);

        // Check if `p.vest.cap` needs to be adjusted based on the new vest rate.
        // Note: adds 10% buffer to the rate, as usual for this parameter.
        uint256 cap = vest.cap();
        uint256 rateWithBuffer = (110 * p.vestTot) / (100 * p.vestTau);
        if (rateWithBuffer > cap) {
            vest.file("cap", rateWithBuffer);
        }

        // Create the proper vesting stream for rewards distribution.
        uint256 vestId = VestInit.create(
            p.vest, VestCreateParams({usr: p.dist, tot: p.vestTot, bgn: p.vestBgn, tau: p.vestTau, eta: 0})
        );

        // Set the `vestId` in `dist`
        VestedRewardsDistributionInit.init(p.dist, VestedRewardsDistributionInitParams({vestId: vestId}));

        // Check if the first distribution is already available and then distribute.
        uint256 unpaid = vest.unpaid(vestId);
        if (unpaid > 0) {
            dist.distribute();
        }

        VestedRewardsDistributionJobLike distJob = VestedRewardsDistributionJobLike(p.distJob);
        distJob.set(p.dist, p.distJobInterval);

        r.vestId = vestId;
        r.distributedAmount = unpaid;

        chainlog.setAddress(p.rewardsKey, p.rewards);
        chainlog.setAddress(p.distKey, p.dist);
    }

    function initLockstakeFarm(FarmingInitParams memory p, address lockstakeEngine)
        internal
        returns (FarmingInitResult memory r)
    {
        address lssky = LockstakeEngineLike(lockstakeEngine).lssky();
        require(p.stakingToken == lssky, "initLockstakeFarm/staking-token-not-lssky");
        r = initFarm(p);
        LockstakeEngineLike(lockstakeEngine).addFarm(p.rewards);
    }

    function updateFarmVest(FarmingUpdateVestParams memory p) internal returns (FarmingUpdateVestResult memory r) {
        require(p.vestTot > 0, "updateFarmVest/vest-tot-zero");
        require(p.vestTau > 0, "updateFarmVest/vest-tau-zero");

        VestedRewardsDistributionLike_1 dist = VestedRewardsDistributionLike_1(p.dist);
        require(dist.vestId() != 0, "updateFarmVest/dist-vest-id-not-set");

        DssVestTransferrableLike vest = DssVestTransferrableLike(dist.dssVest());
        // Note: `vest` is expected to be of type `DssVestTransferrable`
        require(vest.czar() == address(this), "updateFarmVest/vest-czar-mismatch");
        require(vest.gem() == dist.gem(), "updateFarmVest/vest-gem-mismatch");

        ERC20Like rewardsToken = ERC20Like(dist.gem());
        uint256 prevVestId = dist.vestId();

        // Check if there is a distribution to be done in the previous vesting stream.
        uint256 prevUnpaid = vest.unpaid(prevVestId);
        if (prevUnpaid > 0) {
            dist.distribute();
        }

        // Adjust allowance for the new vest
        {
            uint256 currAllowance = rewardsToken.allowance(address(this), address(vest));
            uint256 prevVestTot = vest.tot(prevVestId);
            uint256 prevVestRxd = vest.rxd(prevVestId);
            rewardsToken.approve(address(vest), currAllowance + p.vestTot - (prevVestTot - prevVestRxd));
        }

        // Yank the previous vesting stream.
        vest.yank(prevVestId);

        // Check if vest cap needs adjustment
        {
            uint256 cap = vest.cap();
            uint256 rateWithBuffer = (110 * p.vestTot) / (100 * p.vestTau);
            if (rateWithBuffer > cap) {
                vest.file("cap", rateWithBuffer);
            }
        }

        // Create a new vesting stream for rewards distribution.
        uint256 vestId = VestInit.create(
            address(vest), VestCreateParams({usr: p.dist, tot: p.vestTot, bgn: p.vestBgn, tau: p.vestTau, eta: 0})
        );

        // Set the `vestId` in `dist`
        VestedRewardsDistributionInit.init(p.dist, VestedRewardsDistributionInitParams({vestId: vestId}));

        // Check if the first distribution is already available and then distribute.
        uint256 unpaid = vest.unpaid(vestId);
        if (unpaid > 0) {
            dist.distribute();
        }

        r.prevVestId = prevVestId;
        r.prevDistributedAmount = prevUnpaid;
        r.vestId = vestId;
        r.distributedAmount = unpaid;
    }
}

interface DssVestTransferrableLike {
    function cap() external view returns (uint256);
    function czar() external view returns (address);
    function gem() external view returns (address);
    function file(bytes32 key, uint256 value) external;
    function rxd(uint256 vestId) external view returns (uint256);
    function tot(uint256 vestId) external view returns (uint256);
    function unpaid(uint256 vestId) external view returns (uint256);
    function yank(uint256 vestId) external;
}

interface StakingRewardsLike_1 {
    function owner() external view returns (address);
    function rewardRate() external view returns (uint256);
    function rewardsDistribution() external view returns (address);
    function rewardsToken() external view returns (address);
    function stakingToken() external view returns (address);
}

interface VestedRewardsDistributionLike_1 {
    function dssVest() external view returns (address);
    function distribute() external;
    function gem() external view returns (address);
    function stakingRewards() external view returns (address);
    function vestId() external view returns (uint256);
}

interface ChainlogLike_1 {
    function setAddress(bytes32 key, address addr) external;
}

interface ERC20Like {
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external;
}

interface VestedRewardsDistributionJobLike {
    function set(address dist, uint256 interval) external;
}

interface LockstakeEngineLike {
    function addFarm(address farm) external;
    function lssky() external view returns (address);
}

// src/DssSpell.sol
// SPDX-FileCopyrightText: © 2020 Dai Foundation <www.daifoundation.org>

//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Note: Code matches audited code (https://reports.chainsecurity.com/Sky/ChainSecurity_Sky_EndgameToolkit_Audit.pdf)

interface AllocatorVaultLike {
    function ilk() external view returns (bytes32);
}

interface DaiUsdsLike {
    function daiToUsds(address usr, uint256 wad) external;
}

interface DssLitePsmLike {
    function kiss(address usr) external;
}

interface StarGuardLike {
    function plot(address addr_, bytes32 tag_) external;
}

contract DssSpellAction is DssAction {
    // Provides a descriptive tag for bot consumption
    // This should be modified weekly to provide a summary of the actions
    // Hash: cast keccak -- "$(wget 'https://raw.githubusercontent.com/sky-ecosystem/executive-votes/179a8da3773012065b44a1660b773fbf78029466/2026/executive-vote-2026-07-16-june-msc-staking-rewards-normalization.md' -q -O - 2>/dev/null)"
    string public constant override description = "2026-07-16 MakerDAO Executive Spell | Hash: 0x7ef9ce302cfa0574fa0de8ce87466a7bfda3426e8a12298de1a5db555b3080b1";

    // Set office hours according to the summary
    function officeHours() public pure override returns (bool) {
        return true;
    }

    // ---------- Rates ----------
    // Many of the settings that change weekly rely on the rate accumulator
    // described at https://docs.makerdao.com/smart-contract-modules/rates-module
    // To check this yourself, use the following rate calculation (example 8%):
    //
    // $ bc -l <<< 'scale=27; e( l(1.08)/(60 * 60 * 24 * 365) )'
    //
    // A table of rates can be found at
    //    https://ipfs.io/ipfs/QmVp4mhhbwWGTfbh2BzwQB9eiBrQBKiqcPRZCaAxNUaar6
    //
    // uint256 internal constant X_PCT_RATE = ;

    // ---------- Math ----------
    uint256 internal constant MILLION = 10 ** 6;

    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;

    // ---------- Contracts ----------
    address internal immutable MCD_VAT                        = DssExecLib.vat();
    address internal immutable MCD_JUG                        = DssExecLib.jug();
    address internal immutable MCD_VOW                        = DssExecLib.vow();
    address internal immutable DAI                            = DssExecLib.dai();
    address internal immutable DAI_USDS                       = DssExecLib.getChangelogAddress("DAI_USDS");
    address internal immutable MCD_LITE_PSM_USDC_A            = DssExecLib.getChangelogAddress("MCD_LITE_PSM_USDC_A");
    address internal immutable MCD_IAM_AUTO_LINE              = DssExecLib.getChangelogAddress("MCD_IAM_AUTO_LINE");
    address internal immutable ALLOCATOR_SPARK_A_VAULT        = DssExecLib.getChangelogAddress("ALLOCATOR_SPARK_A_VAULT");
    address internal immutable SPARK_SUBPROXY                 = DssExecLib.getChangelogAddress("SPARK_SUBPROXY");
    address internal immutable ALLOCATOR_BLOOM_A_VAULT        = DssExecLib.getChangelogAddress("ALLOCATOR_BLOOM_A_VAULT");
    address internal immutable GROVE_SUBPROXY                 = DssExecLib.getChangelogAddress("GROVE_SUBPROXY");
    address internal immutable KEEL_SUBPROXY                  = DssExecLib.getChangelogAddress("KEEL_SUBPROXY");
    address internal immutable ALLOCATOR_OBEX_A_VAULT         = DssExecLib.getChangelogAddress("ALLOCATOR_OBEX_A_VAULT");
    address internal immutable OBEX_SUBPROXY                  = DssExecLib.getChangelogAddress("OBEX_SUBPROXY");
    address internal immutable SKYBASE_SUBPROXY               = DssExecLib.getChangelogAddress("SKYBASE_SUBPROXY");
    address internal immutable REWARDS_DIST_LSSKY_SKY         = DssExecLib.getChangelogAddress("REWARDS_DIST_LSSKY_SKY");
    address internal immutable RWA001_A_URN                   = DssExecLib.getChangelogAddress("RWA001_A_URN");
    address internal immutable MIP21_LIQUIDATION_ORACLE       = DssExecLib.getChangelogAddress("MIP21_LIQUIDATION_ORACLE");
    address internal immutable SPARK_STARGUARD                = DssExecLib.getChangelogAddress("SPARK_STARGUARD");
    address internal immutable GROVE_STARGUARD                = DssExecLib.getChangelogAddress("GROVE_STARGUARD");
    address internal immutable PRYSM_STARGUARD                = DssExecLib.getChangelogAddress("PRYSM_STARGUARD");
    address internal immutable SAFE_HARBOR_AGREEMENT          = DssExecLib.getChangelogAddress("SAFE_HARBOR_AGREEMENT");

    address internal constant OSERO_ALM_PROXY                 = 0x6d370e359e9cbd0Fd35Bb38fAF705D84238CB884;
    address internal constant EMSP_STUSDS_RATE_S_DISS_BUD_FAB = 0xb3Fd827F58989cFacFE50d2F8e86A1113b6066D1;
    address internal constant EMSP_STUSDS_WIPE_PARAM_FAB      = 0x768D5Ce639c7E7d51E1244E2634d6149bd0d8096;
    address internal constant EMSP_STUSDS_RATE_SETTER_HALT    = 0x91808ABeCd82495a4a7bf27d80C8c1e89de9effb;

    // ---------- Wallets ----------
    address internal constant DEMAND_SIDE_BUFFER_MULTISIG  = 0x5e2fEc3a3C4E63A422e45C1BB83EdB3a5aD0543B;
    address internal constant CORE_COUNCIL_BUDGET_MULTISIG = 0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364;

    // ---------- Spark Spell ----------
    address internal constant SPARK_SPELL      = 0xC1090e8fEE666868622a2F1e870185F944108Ee2;
    bytes32 internal constant SPARK_SPELL_HASH = 0xa7b0b6c470169f40016d354a8944f9e5f3f787159fec5192694e8f1ddbc7f26f;

    // ---------- Grove Spell ----------
    address internal constant GROVE_SPELL      = 0x4f1318bC0490dC7C7F8230F1dd91A4A2e4694134;
    bytes32 internal constant GROVE_SPELL_HASH = 0x38dd6399490f19d7a7e17a6eafda5d2ad92f9395c08efe2fdbacfda3b6d36a89;

    // ---------- Osero Spell ----------
    address internal constant OSERO_SPELL      = 0x5D9311fcDda62c08EB9F1115Ca804881a6660445;
    bytes32 internal constant OSERO_SPELL_HASH = 0x7dca6bc3a3097897198698a674bc824fd3bbb1c9b94c655cd0d78c49db2b9f3e;

    function actions() public override {
        // ---------- Monthly Settlement Cycle for June 2026 ----------
        // Forum: https://forum.skyeco.com/t/msc-10-settlement-summary-june-2026/28038
        // Atlas: https://sky-atlas.io/#6f8d5065-d6ff-4add-9a28-eadeffa7ed1a

        // Mint 16,923,682 USDS debt in ALLOCATOR-SPARK-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_SPARK_A_VAULT, 16_923_682 * WAD);

        // Send 9,746,443 USDS from the surplus buffer to the SPARK_SUBPROXY
        _transferUsds(SPARK_SUBPROXY, 9_746_443 * WAD);

        // Mint 12,342,158 USDS debt in ALLOCATOR-BLOOM-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_BLOOM_A_VAULT, 12_342_158 * WAD);

        // Send 2,328,332 USDS from the surplus buffer to the GROVE_SUBPROXY
        _transferUsds(GROVE_SUBPROXY, 2_328_332 * WAD);

        // Send 34,902 USDS from the surplus buffer to the Demand-side Buffer (0x5e2fEc3a3C4E63A422e45C1BB83EdB3a5aD0543B)
        _transferUsds(DEMAND_SIDE_BUFFER_MULTISIG, 34_902 * WAD);

        // Send 77,284 USDS from the surplus buffer to the KEEL_SUBPROXY
        _transferUsds(KEEL_SUBPROXY, 77_284 * WAD);

        // Mint 3,450,783 USDS debt in ALLOCATOR-OBEX-A and transfer the amount to the surplus buffer.
        _takeAllocatorPayment(ALLOCATOR_OBEX_A_VAULT, 3_450_783 * WAD);

        // Send 1,519,539 USDS from the surplus buffer to the OBEX_SUBPROXY
        _transferUsds(OBEX_SUBPROXY, 1_519_539 * WAD);

        // Send 204,242 USDS from the surplus buffer to the SKYBASE_SUBPROXY
        _transferUsds(SKYBASE_SUBPROXY, 204_242 * WAD);

        // Send 3,378,069 USDS from the surplus buffer to the Core Council Buffer (0x210CFcF53d1f9648C1c4dcaEE677f0Cb06914364)
        _transferUsds(CORE_COUNCIL_BUDGET_MULTISIG, 3_378_069 * WAD);

        // ---------- LSSKY->SKY Rewards Normalization ----------
        // Forum: https://forum.skyeco.com/t/lssky-to-sky-rewards-sky-rewards-for-sky-stakers-normalization-configuration/27721/26
        // Atlas: https://sky-atlas.io/#a98a1bfe-5713-43f5-a8bd-83c5808900b8

        // Update LSSKY->SKY Farm vest by calling `TreasuryFundedFarmingInit.updateFarmVest()` with params:
        TreasuryFundedFarmingInit.updateFarmVest(FarmingUpdateVestParams({
            // dist: 0x675671A8756dDb69F7254AFB030865388Ef699Ee
            dist: REWARDS_DIST_LSSKY_SKY,
            // vestTot: 286,714,697 SKY
            vestTot: 286_714_697 * WAD,
            // vestBgn: block.timestamp
            vestBgn: block.timestamp,
            // vestTau: 90 days
            vestTau: 90 days
        }));

        // ---------- RWA001-A Offboarding Spell 2 ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-rwa001-a-offboarding/27706/5
        // Forum: https://forum.skyeco.com/t/technical-scope-of-rwa001-a-offboarding/27706/16

        // Call MIP21_LIQUIDATION_ORACLE.cull with:
        // MIP21_LIQUIDATION_ORACLE being 0x88f88Bb9E66241B73B84f3A6E197FbBa487b1E30
        RwaLiquidationOracleAbstract(MIP21_LIQUIDATION_ORACLE).cull(
            // bytes32 ilk being "RWA001-A"
            "RWA001-A",
            // address urn being RWA001_A_URN
            RWA001_A_URN
        );

        // ---------- Add STUSDS_MOM Emergency Spells to the Chainlog ----------
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-stusdsmom-deploy-and-replacement/27967/5
        // Forum: https://forum.skyeco.com/t/technical-scope-of-the-new-stusdsmom-deploy-and-replacement/27967/7

        // Add the following Emergency Spells related to the STUSDS_MOM to the chainlog:
        // EMSP_STUSDS_RATE_S_DISS_BUD_FAB: 0xb3Fd827F58989cFacFE50d2F8e86A1113b6066D1
        DssExecLib.setChangelogAddress("EMSP_STUSDS_RATE_S_DISS_BUD_FAB", EMSP_STUSDS_RATE_S_DISS_BUD_FAB);

        // EMSP_STUSDS_WIPE_PARAM_FAB: 0x768D5Ce639c7E7d51E1244E2634d6149bd0d8096
        DssExecLib.setChangelogAddress("EMSP_STUSDS_WIPE_PARAM_FAB", EMSP_STUSDS_WIPE_PARAM_FAB);

        // EMSP_STUSDS_RATE_SETTER_HALT: 0x91808ABeCd82495a4a7bf27d80C8c1e89de9effb
        DssExecLib.setChangelogAddress("EMSP_STUSDS_RATE_SETTER_HALT", EMSP_STUSDS_RATE_SETTER_HALT);

        // Note: bump Chainlog version
        DssExecLib.setChangelogVersion("1.20.18");

        // ---------- Whitelist Osero DPAU ALMProxy on LitePSM ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-osero-for-upcoming-spell/28023
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Whitelist the Osero ALMProxy at 0x6d370e359e9cbd0Fd35Bb38fAF705D84238CB884 on Sky LitePSM (MCD_LITE_PSM_USDC_A) via kiss
        DssLitePsmLike(MCD_LITE_PSM_USDC_A).kiss(OSERO_ALM_PROXY);

        // ---------- Adjust Osero DC-IAM Parameters ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-osero-for-upcoming-spell/28023
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Note: use DssExecLib.setIlkAutoLineParameters() to update multiple ALLOCATOR-PRYSM-A DC-IAM parameters at the same time:
        DssExecLib.setIlkAutoLineParameters({
            _ilk: "ALLOCATOR-PRYSM-A",
            // Decrease ALLOCATOR-PRYSM-A `maxLine` from 10 million USDS to 5 million USDS
            _amount: 5 * MILLION,
            // Decrease ALLOCATOR-PRYSM-A `gap` from 10 million USDS to 1 million USDS
            _gap: 1 * MILLION,
            // Leave ALLOCATOR-PRYSM-A `duty` and `ttl` unchanged at 0% and 24 hours (86,400 seconds) respectively
            _ttl: 86_400 seconds
            // Note: This operation does not modify `duty`, as this function does not support updating it.
        });

        // Note: Apply the updated ALLOCATOR-PRYSM-A AutoLine configuration immediately, syncing its live MCD_VAT debt ceiling.
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).exec("ALLOCATOR-PRYSM-A");

        // ---------- Update SafeHarbor Agreement ----------
        // Atlas: https://sky-atlas.io/#fcd868db-4a91-4ee0-baf5-1ebd40fc651e

        // Note: Code below is generated via Safe Harbor script, thus the formatting may be different than the usual spell instructions format
        bytes[] memory calldatas = new bytes[](1);

        // Add accounts to eip155:1 chain: 0xb3Fd827F58989cFacFE50d2F8e86A1113b6066D1, 0x768D5Ce639c7E7d51E1244E2634d6149bd0d8096, 0x91808ABeCd82495a4a7bf27d80C8c1e89de9effb
        calldatas[0] = hex'46c2b7340000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000086569703135353a3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a3078623346643832374635383938396346616346453530643246386538364131313133623630363644310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002a3078373638443543653633396337453764353145313234344532363334643631343962643064383039360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783931383038414265436438323439356134613762663237643830433863316538396465396566666200000000000000000000000000000000000000000000';

        _updateSafeHarbor(calldatas);

        // ---------- Spark Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-spark-for-upcoming-spell/28029
        // Atlas: https://sky-atlas.io/#ea73f176-0b94-4e93-b1ee-ca498ac5a6c6
        // Atlas: https://sky-atlas.io/#8dd2eb27-a760-4287-89cf-7b5bdb0c5d7c
        // Atlas: https://sky-atlas.io/#6a4870fa-73f1-4d49-b7ee-d531fb59a971
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xd177bc28b65afb23dc39a5e7cfdded7084b3b722b230e08d7067b68fa0f4486a
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xdde478db4ba5882a5d48d19fdbae057fd703688e4f1e16fb673407fc08476a9f
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0xf99372ccca4b99dd04dc0ddb038e949b62f4d25810b0203572dc90bce025e805
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x2df281a276e0c17eff9a05e65bfc05937c2f600edec1a82386a6efb6dbe9d63d
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x3cb4165f1357d553445b0de790e4e8b4a71358f42f39d35f7de51b308ade558c
        // Poll: https://snapshot.org/#/s:sparkfi.eth/proposal/0x451bb53f80ad2906ff06cc3d03c88a6b09f350db371c4782e0621e26a1d55a43

        // Whitelist Spark spell with address 0xC1090e8fEE666868622a2F1e870185F944108Ee2 and codehash 0xa7b0b6c470169f40016d354a8944f9e5f3f787159fec5192694e8f1ddbc7f26f in SPARK_STARGUARD, direct execution: No
        StarGuardLike(SPARK_STARGUARD).plot(SPARK_SPELL, SPARK_SPELL_HASH);

        // ---------- Grove Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-grove-for-upcoming-spell/28024
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Whitelist Grove spell with address 0x4f1318bC0490dC7C7F8230F1dd91A4A2e4694134 and codehash 0x38dd6399490f19d7a7e17a6eafda5d2ad92f9395c08efe2fdbacfda3b6d36a89 in GROVE_STARGUARD, direct execution: No
        StarGuardLike(GROVE_STARGUARD).plot(GROVE_SPELL, GROVE_SPELL_HASH);

        // ---------- Osero Proxy Spell ----------
        // Forum: https://forum.skyeco.com/t/july-16-2026-proposed-changes-to-osero-for-upcoming-spell/28023
        // Poll: https://vote.sky.money/polling/QmUnVyGg

        // Whitelist Osero spell with address 0x5D9311fcDda62c08EB9F1115Ca804881a6660445 and codehash 0x7dca6bc3a3097897198698a674bc824fd3bbb1c9b94c655cd0d78c49db2b9f3e in PRYSM_STARGUARD, direct execution: No
        StarGuardLike(PRYSM_STARGUARD).plot(OSERO_SPELL, OSERO_SPELL_HASH);
    }

    // ---------- Helper Functions ----------

    /// @notice Wraps the operations required to transfer USDS from the surplus buffer.
    /// @param usr The USDS receiver.
    /// @param wad The USDS amount in wad precision (10 ** 18).
    function _transferUsds(address usr, uint256 wad) internal {
        // Note: Enforce whole units to avoid rounding errors
        require(wad % WAD == 0, "transferUsds/non-integer-wad");
        // Note: DssExecLib currently only supports Dai transfers from the surplus buffer.
        DssExecLib.sendPaymentFromSurplusBuffer(address(this), wad / WAD);
        // Note: Approve DAI_USDS for the amount sent to be able to convert it.
        GemAbstract(DAI).approve(DAI_USDS, wad);
        // Note: Convert Dai to USDS for `usr`.
        DaiUsdsLike(DAI_USDS).daiToUsds(usr, wad);
    }

    /// @notice Wraps the operations required to take a payment from a Prime agent
    /// @dev This function effectively increases the debt of the associated Allocator Vault,
    ///      regardless if there is enough room in its debt ceiling.
    /// @param vault The address of the allocator vault
    /// @param wad The amount in wad precision (10 ** 18)
    function _takeAllocatorPayment(address vault, uint256 wad) internal {
        require(wad > 0, "takeAllocatorPayment/zero-amount");
        bytes32 ilk = AllocatorVaultLike(vault).ilk();
        uint256 rate = JugAbstract(MCD_JUG).drip(ilk);
        require(rate > 0, "takeAllocatorPayment/jug-ilk-not-initialized");
        // Note: divup - rounds up in favor of Core.
        uint256 dart = ((wad * RAY - 1) / rate) + 1;
        require(dart <= uint256(type(int256).max), "takeAllocatorPayment/dart-too-large");
        // Note: Take the amount needed, but keep it in the Vow.
        //       This basically generates both sin[vow] and dai[vow] at the same time.
        VatAbstract(MCD_VAT).suck(MCD_VOW, MCD_VOW, dart * rate);
        // Note: Increase the outstanding debt of the vault, while reducing sin[vow], canceling out the sin generated by vat.suck.
        //       The net effect is that dai[vow] and urn[vault].art increase.
        VatAbstract(MCD_VAT).grab(ilk, vault, address(0), MCD_VOW, 0, int256(dart));
    }

    /// @notice Wraps the operations required to update the Safe Harbor agreement.
    /// @dev This function executes pre-encoded function calls on the Safe Harbor agreement contract.
    ///      The calldatas array contains ABI-encoded function calls (selector + parameters) that
    ///      will be executed sequentially on the Safe Harbor agreement contract.
    /// @param calldatas Array of ABI-encoded function calls to execute on the Safe Harbor agreement contract
    function _updateSafeHarbor(bytes[] memory calldatas) internal {
        for (uint256 i = 0; i < calldatas.length; i++) {
            (bool success,) = SAFE_HARBOR_AGREEMENT.call(calldatas[i]);
            require(success, "updateSafeHarbor/safe-harbor-update-failed");
        }
    }
}

contract DssSpell is DssExec {
    constructor() DssExec(block.timestamp + 30 days, address(new DssSpellAction())) {}
}
