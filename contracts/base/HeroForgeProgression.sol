// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./HeroForgeItems.sol";

/**
 * @title  HeroForgeProgression
 * @notice Handles XP granting and stat upgrades.
 *         XP is granted only by the game master after verified gameplay.
 *         Players spend XP to permanently increment strength, speed, or defence.
 *         Each upgrade costs exactly XP_PER_UPGRADE (10) XP and raises the
 *         chosen stat by 1, up to a maximum of MAX_STAT (100).
 *         Abstract: not deployed directly.
 */
abstract contract HeroForgeProgression is HeroForgeItems {

    /**
     * @notice Credit XP to a character. Game master only.
     *         Called after the game verifies a player completed an action.
     *
     * @param charId  Token ID of the character to reward.
     * @param amount  Amount of XP to add.
     */
    function earnXP(uint256 charId, uint256 amount)
        external
        onlyGameMaster
    {
        // Checks
        if (!isCharacter[charId]) revert NotACharacter();

        // Effects
        characters[charId].xp += amount;

        emit XPEarned(charId, amount, characters[charId].xp);
    }

    /**
     * @notice Spend XP to permanently increment one stat by 1 point.
     *         Costs exactly XP_PER_UPGRADE (10) XP per call.
     *         Valid stat names: "strength", "speed", "defence".
     *
     * @param charId  Token ID of the character.
     * @param stat    The stat to upgrade — "strength", "speed", or "defence".
     */
    function spendXP(uint256 charId, string calldata stat)
        external
        onlyCharacterOwner(charId)
    {
        Character storage c = characters[charId];

        // Checks — verify XP balance before touching any state
        if (c.xp < XP_PER_UPGRADE) revert InsufficientXP();

        uint256 oldValue;
        uint256 newValue;

        if (_strEq(stat, "strength")) {
            oldValue = c.strength;
            newValue = oldValue + 1;
            if (newValue > MAX_STAT) revert StatCapReached();
            // Effects
            c.xp       -= XP_PER_UPGRADE;
            c.strength  = newValue;

        } else if (_strEq(stat, "speed")) {
            oldValue = c.speed;
            newValue = oldValue + 1;
            if (newValue > MAX_STAT) revert StatCapReached();
            // Effects
            c.xp   -= XP_PER_UPGRADE;
            c.speed = newValue;

        } else if (_strEq(stat, "defence")) {
            oldValue = c.defence;
            newValue = oldValue + 1;
            if (newValue > MAX_STAT) revert StatCapReached();
            // Effects
            c.xp      -= XP_PER_UPGRADE;
            c.defence  = newValue;

        } else {
            revert InvalidStat();
        }

        emit StatUpgraded(charId, stat, oldValue, newValue);
    }
}
