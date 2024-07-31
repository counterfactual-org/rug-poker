// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { SHARES_GAME, SHARES_TREASURY } from "../MinterConstants.sol";
import { MinterConfig, MinterStorage } from "../MinterStorage.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { INFT } from "src/interfaces/INFT.sol";

library MinterConfigs {
    uint256 constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;

    error InvalidAddress();
    error InvalidPrice();
    error InvalidShares();

    function minterStorage() internal pure returns (MinterStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function latest() internal view returns (MinterConfig memory) {
        MinterStorage storage s = minterStorage();

        return s.configs[s.configVersion];
    }

    function nft() internal view returns (INFT) {
        return INFT(minterStorage().nft);
    }

    function config() external view returns (MinterConfig memory) {
        return MinterConfigs.latest();
    }

    function updateTreasury(address _treasury) internal {
        if (_treasury == address(0)) revert InvalidAddress();

        minterStorage().treasury = _treasury;
    }

    function updateGame(address _game) internal {
        if (_game == address(0)) revert InvalidAddress();

        minterStorage().game = _game;
    }

    function updateConfig(MinterConfig memory c) internal {
        if (c.price == 0) revert InvalidPrice();
        if (c.shares[SHARES_TREASURY] < 30) revert InvalidShares();
        if (c.shares[SHARES_TREASURY] + c.shares[SHARES_GAME] > 100) revert InvalidShares();

        MinterStorage storage s = minterStorage();
        uint256 version = s.configVersion + 1;
        s.configs[version] = c;
        s.configVersion = version;
    }
}
