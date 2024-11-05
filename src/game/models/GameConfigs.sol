// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { HOLE_CARDS } from "../GameConstants.sol";
import { GameConfig, GameStorage } from "../GameStorage.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { INFT } from "src/interfaces/INFT.sol";

library GameConfigs {
    uint256 constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;

    error GasLimitTooLow();
    error InvalidAddress();
    error InvalidNumber();
    error InvalidPercentage();
    error InvalidAttackFees();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function latest() internal view returns (GameConfig memory) {
        GameStorage storage s = gameStorage();

        return s.configs[s.configVersion];
    }

    function nft() internal view returns (INFT) {
        return INFT(gameStorage().nft);
    }

    function erc721() internal view returns (IERC721) {
        return IERC721(gameStorage().nft);
    }

    function treasury() internal view returns (address) {
        return gameStorage().treasury;
    }

    function evaluator9() internal view returns (IEvaluator) {
        return IEvaluator(gameStorage().evaluator9);
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) internal {
        if (_randomizerGasLimit < MIN_RANDOMIZER_GAS_LIMIT) revert GasLimitTooLow();

        gameStorage().randomizerGasLimit = _randomizerGasLimit;
    }

    function updateEvaluator9(address _evaluator) internal {
        if (_evaluator == address(0)) revert InvalidAddress();

        gameStorage().evaluator9 = _evaluator;
    }

    function updateTreasury(address _treasury) internal {
        if (_treasury == address(0)) revert InvalidAddress();

        gameStorage().treasury = _treasury;
    }

    function updateConfig(GameConfig memory c) internal {
        if (c.maxJokers == 0 || c.maxJokers > HOLE_CARDS) revert InvalidNumber();
        if (c.minBootyPercentage >= c.maxBootyPercentage || c.maxBootyPercentage > 100) {
            revert InvalidPercentage();
        }
        if (c.minDurability == 0 || c.maxDurability <= c.minDurability) revert InvalidNumber();
        if (c.minPowerUpPercentage >= c.maxPowerUpPercentage || c.maxPowerUpPercentage > 100) {
            revert InvalidPercentage();
        }
        if (c.bogoPercentage > 100) revert InvalidPercentage();

        GameStorage storage s = gameStorage();
        uint256 version = s.configVersion + 1;
        s.configs[version] = c;
        s.configVersion = version;
    }
}
