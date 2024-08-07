// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { HOLE_CARDS_SMALL } from "../GameConstants.sol";
import { GameConfig, GameStorage } from "../GameStorage.sol";

import { IERC721 } from "forge-std/interfaces/IERC721.sol";
import { IEvaluator } from "src/interfaces/IEvaluator.sol";
import { INFT } from "src/interfaces/INFT.sol";

library GameConfigs {
    uint256 constant MIN_RANDOMIZER_GAS_LIMIT = 100_000;

    error GasLimitTooLow();
    error InvalidAddress();
    error InvalidNumber();
    error InvalidPeriod();
    error InvalidPercentage();
    error InvalidBootyPercentages();
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

    function evaluator5() internal view returns (IEvaluator) {
        return IEvaluator(gameStorage().evaluator5);
    }

    function evaluator7() internal view returns (IEvaluator) {
        return IEvaluator(gameStorage().evaluator7);
    }

    function updateRandomizerGasLimit(uint256 _randomizerGasLimit) internal {
        if (_randomizerGasLimit < MIN_RANDOMIZER_GAS_LIMIT) revert GasLimitTooLow();

        gameStorage().randomizerGasLimit = _randomizerGasLimit;
    }

    function updateEvaluator5(address _evaluator) internal {
        if (_evaluator == address(0)) revert InvalidAddress();

        gameStorage().evaluator5 = _evaluator;
    }

    function updateEvaluator7(address _evaluator) internal {
        if (_evaluator == address(0)) revert InvalidAddress();

        gameStorage().evaluator7 = _evaluator;
    }

    function updateTreasury(address _treasury) internal {
        if (_treasury == address(0)) revert InvalidAddress();

        gameStorage().treasury = _treasury;
    }

    function updateConfig(GameConfig memory c) internal {
        if (c.maxCards == 0) revert InvalidNumber();
        if (c.maxJokers == 0 || c.maxJokers > HOLE_CARDS_SMALL) revert InvalidNumber();
        if (c.maxAttacks == 0) revert InvalidNumber();
        if (c.minBootyPercentage >= c.maxBootyPercentage || c.maxBootyPercentage >= 100) {
            revert InvalidBootyPercentages();
        }
        if (c.maxBootyCards == 0 || c.maxBootyCards > HOLE_CARDS_SMALL) revert InvalidNumber();
        if (c.minDurability == 0 || c.maxDurability <= c.minDurability) revert InvalidNumber();
        if (c.minDuration < 1 days) revert InvalidPeriod();
        if (c.bogoPercentage > 100) revert InvalidPercentage();
        if (c.attackPeriod < 1 hours) revert InvalidPeriod();

        GameStorage storage s = gameStorage();
        uint256 version = s.configVersion + 1;
        s.configs[version] = c;
        s.configVersion = version;
    }
}
