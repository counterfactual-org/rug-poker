// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { Card, GameStorage, Player } from "../GameStorage.sol";
import { Cards } from "./Cards.sol";
import { Configs } from "./Configs.sol";
import { Rewards } from "./Rewards.sol";
import { INFT } from "src/interfaces/INFT.sol";
import { INFTMinter } from "src/interfaces/INFTMinter.sol";

library Players {
    using Cards for Card;

    event CheckpointPlayer(address indexed account);

    error MaxCardsStaked();
    error Forbidden();
    error Underuse();
    error WornOut();
    error DurationNotElapsed();
    error InsufficientFee();

    function gameStorage() internal pure returns (GameStorage storage s) {
        assembly {
            s.slot := 0
        }
    }

    function get(address account) internal view returns (Player storage self) {
        return gameStorage().playerOf[account];
    }

    function init(address account) internal returns (Player storage self) {
        self = get(account);
        self.account = account;
    }

    function initialized(Player storage self) internal view returns (bool) {
        return self.account != address(0);
    }

    function isImmune(Player storage self) internal view returns (bool) {
        uint256 lastDefendedAt = self.lastDefendedAt;
        return lastDefendedAt > 0 && block.timestamp < lastDefendedAt + Configs.latest().immunePeriod;
    }

    function updateLastDefendedAt(Player storage self) internal {
        self.lastDefendedAt = uint64(block.timestamp);
    }

    function addCard(Player storage self, uint256 tokenId) internal {
        address account = self.account;
        uint256 cards = self.cards;
        if (cards >= Configs.latest().maxCards) revert MaxCardsStaked();
        increaseFreeMintingIfHasNotPlayed(self);

        checkpoint(self);

        Card storage card = Cards.get(tokenId);
        if (!card.initialized()) {
            card = Cards.init(tokenId, account);
        }
        card.add();

        self.cards = cards + 1;
        updateLastDefendedAt(self);
    }

    function removeCard(Player storage self, uint256 tokenId) internal {
        Card storage card = Cards.get(tokenId);
        if (card.owner != self.account) revert Forbidden();
        if (card.underuse) revert Underuse();
        if (!card.wornOut() && card.durationElapsed()) revert DurationNotElapsed();

        checkpoint(self);

        card.remove(false);
        self.cards -= 1;
    }

    function burnCard(Player storage self, uint256 tokenId) internal {
        Card storage card = Cards.get(tokenId);
        if (card.owner != self.account) revert Forbidden();
        if (card.underuse) revert Underuse();
        if (card.durability == 0) revert WornOut();

        checkpoint(self);

        card.remove(true);
        self.cards -= 1;
    }

    function deductFee(Player storage self, uint8 bootyTier) internal returns (uint256 fee) {
        GameStorage storage s = gameStorage();
        uint256 acc = s.accReward[self.account];
        fee = Configs.latest().attackFees[bootyTier];
        if (acc < fee) revert InsufficientFee();
        s.accReward[self.account] = acc - fee;
    }

    function increaseFreeMintingIfHasNotPlayed(Player storage self) internal {
        if (!self.hasPlayed) {
            address minter = INFT(gameStorage().nft).minter();
            INFTMinter(minter).increaseFreeMintingOf(self.account);
            self.hasPlayed = true;
        }
    }

    function increaseFreeMintingIfHasNotAttacked(Player storage self, address defender) internal {
        GameStorage storage s = gameStorage();
        if (!s.hasAttacked[self.account][defender]) {
            address nftMinter = INFT(s.nft).minter();
            INFTMinter(nftMinter).increaseFreeMintingOf(self.account);
            s.hasAttacked[self.account][defender] = true;
        }
    }

    function checkpoint(Player storage self) internal {
        Rewards.checkpoint();

        GameStorage storage s = gameStorage();

        address account = self.account;
        uint256 shares = s.sharesOf[account];
        if (shares > 0) {
            s.accReward[account] += shares * s.accRewardPerShare / 1e12 - s.rewardDebt[account];
        }

        emit CheckpointPlayer(account);
    }
}
