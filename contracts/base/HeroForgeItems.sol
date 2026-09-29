// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./HeroForgeCharacters.sol";

/**
 * @title  HeroForgeItems
 * @notice Handles item NFT minting, equipping to characters, and unequipping.
 *         Items use token IDs starting at ITEM_OFFSET (1_000_001+) so they
 *         never collide with character IDs (1 … 999_999).
 *         Abstract: not deployed directly.
 */
abstract contract HeroForgeItems is HeroForgeCharacters {

    // ─── Minting ──────────────────────────────────────────────────────────────

    /**
     * @notice Mint a new item NFT to a player address.
     *         Only the game master can call this.
     *
     * @param  to       Recipient wallet address.
     * @param  itemType Label describing the item e.g. "sword", "shield".
     * @return itemId   The newly minted item's token ID.
     */
    function mintItem(address to, string calldata itemType)
        external
        onlyGameMaster
        returns (uint256)
    {
        _itemCounter++;
        uint256 itemId = ITEM_OFFSET + _itemCounter;

        // Effects
        items[itemId] = Item({ itemType: itemType, equippedTo: 0 });

        // Interactions
        _safeMint(to, itemId);

        emit ItemMinted(itemId, itemType, to);
        return itemId;
    }

    // ─── Equip ────────────────────────────────────────────────────────────────

    /**
     * @notice Attach an item to a character.
     *         Caller must own both the character and the item.
     *         An item can only be equipped to one character at a time.
     *
     * @param charId Token ID of the character.
     * @param itemId Token ID of the item to equip.
     */
    function equipItem(uint256 charId, uint256 itemId)
        external
        onlyCharacterOwner(charId)
    {
        // Checks
        if (!isCharacter[charId])          revert NotACharacter();
        if (ownerOf(itemId) != msg.sender) revert NotItemOwner();
        if (items[itemId].equippedTo != 0) revert ItemAlreadyEquipped();

        // Effects
        items[itemId].equippedTo = charId;
        _equippedItems[charId].push(itemId);
        hasEquippedItems[charId] = true;

        emit ItemEquipped(charId, itemId, msg.sender);
    }

    /**
     * @notice Remove an item from a character.
     *         Caller must own the character.
     *         After removal the item becomes freely transferable again.
     *
     * @param charId Token ID of the character.
     * @param itemId Token ID of the item to unequip.
     */
    function unequipItem(uint256 charId, uint256 itemId)
        external
        onlyCharacterOwner(charId)
    {
        // Checks
        if (items[itemId].equippedTo != charId) revert ItemNotEquippedToCharacter();

        // Effects
        items[itemId].equippedTo = 0;
        _removeFromEquipped(charId, itemId);

        // Clear the transfer-lock flag only when the last item is removed
        if (_equippedItems[charId].length == 0) {
            hasEquippedItems[charId] = false;
        }

        emit ItemUnequipped(charId, itemId, msg.sender);
    }

    // ─── Views ────────────────────────────────────────────────────────────────

    /**
     * @notice Return the full Item struct for a given token ID.
     * @param  itemId Token ID of the item.
     */
    function getItem(uint256 itemId)
        external
        view
        returns (Item memory)
    {
        if (bytes(items[itemId].itemType).length == 0) revert NotAnItem();
        return items[itemId];
    }

    /**
     * @notice Return all item IDs currently equipped to a character.
     * @param  charId Token ID of the character.
     */
    function getEquippedItems(uint256 charId)
        external
        view
        returns (uint256[] memory)
    {
        if (!isCharacter[charId]) revert NotACharacter();
        return _equippedItems[charId];
    }

    // ─── Internal Helpers ─────────────────────────────────────────────────────

    /**
     * @dev Remove itemId from the equipped list of charId.
     *      Swap-and-pop keeps the operation O(n) without leaving gaps.
     *      Expected n is small (typical inventory < 10 items).
     */
    function _removeFromEquipped(uint256 charId, uint256 itemId) internal {
        uint256[] storage equipped = _equippedItems[charId];
        uint256 len = equipped.length;
        for (uint256 i = 0; i < len; i++) {
            if (equipped[i] == itemId) {
                equipped[i] = equipped[len - 1];
                equipped.pop();
                break;
            }
        }
    }

    /**
     * @dev Compare two strings by their keccak256 hashes.
     *      Used in spendXP to route the stat upgrade without a lookup table.
     */
    function _strEq(string calldata a, string memory b)
        internal
        pure
        returns (bool)
    {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
