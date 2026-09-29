// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./base/HeroForgeProgression.sol";

/**
 * @title  HeroForge
 * @author Rahul
 * @notice The single deployed contract for the HeroForge GameFi system.
 *
 *         Inherits the full feature set through the chain:
 *           HeroForgeStorage         → state, structs, errors, events, modifiers
 *           └── HeroForgeCharacters  → mintCharacter, getCharacter
 *                 └── HeroForgeItems → mintItem, equipItem, unequipItem, views
 *                       └── HeroForgeProgression → earnXP, spendXP
 *                             └── HeroForge (this) → constructor, transferFrom, setGameMaster
 *
 *         Only this contract is compiled to a deployable artifact.
 *         All base contracts are abstract.
 *
 * Token ID ranges
 * ───────────────
 *   Characters :   1 … 999 999
 *   Items      :   1 000 001 … (1 000 000 + _itemCounter)
 *
 * Access roles
 * ────────────
 *   owner      → setGameMaster()
 *   gameMaster → mintItem(), earnXP()
 *   tokenOwner → equipItem(), unequipItem(), spendXP(), transfer (when unlocked)
 *   anyone     → mintCharacter(), all view functions
 */
contract HeroForge is HeroForgeProgression {

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _gameMaster Address authorised to mint items and grant XP.
     *                    The deployer (owner) can rotate this at any time
     *                    via setGameMaster() without redeploying.
     */
    constructor(address _gameMaster)
        ERC721("HeroForge", "HERO")
        Ownable(msg.sender)
    {
        gameMaster = _gameMaster;
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    /**
     * @notice Replace the game master address. Owner only.
     *         Use this if the current game master key is compromised.
     *
     * @param _newGameMaster New game master wallet address.
     */
    function setGameMaster(address _newGameMaster) external onlyOwner {
        address old = gameMaster;
        gameMaster  = _newGameMaster;
        emit GameMasterUpdated(old, _newGameMaster);
    }

    // ─── Transfer Lock ────────────────────────────────────────────────────────

    /**
     * @dev Override ERC-721 transferFrom to enforce two locks:
     *
     *      1. A CHARACTER with equipped items cannot be transferred.
     *         Prevents the new owner controlling a character whose items
     *         still belong to a different equip relationship.
     *
     *      2. An ITEM that is currently equipped cannot be transferred.
     *         Prevents stripping items from under a character mid-session.
     *
     *      Both revert with a custom error — no string messages.
     */
    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
    {
        // Lock 1 — character carrying items
        if (isCharacter[tokenId] && hasEquippedItems[tokenId]) {
            revert CharacterHasEquippedItems();
        }
        // Lock 2 — item currently equipped
        if (!isCharacter[tokenId] && items[tokenId].equippedTo != 0) {
            revert ItemAlreadyEquipped();
        }

        super.transferFrom(from, to, tokenId);
    }
}
