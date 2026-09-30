// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  HeroForge
 * @author Rahul
 * @notice GameFi contract — player characters and their items are ERC-721 NFTs
 *         with fully on-chain progression. Characters earn XP, spend it to
 *         upgrade stats, and equip items. A character carrying equipped items
 *         is transfer-locked until those items are removed.
 *
 * Token ID ranges
 * ───────────────
 *   Characters :   1 … 999 999
 *   Items      :   1 000 001 … (1 000 000 + _itemCounter)
 *
 * Access roles
 * ────────────
 *   owner      → set / rotate gameMaster address
 *   gameMaster → mintItem(), earnXP()
 *   tokenOwner → equipItem(), unequipItem(), spendXP(), transfer (when unlocked)
 *   anyone     → mintCharacter(), all view functions
 */
contract HeroForge is ERC721, Ownable {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant MAX_STAT       = 100;
    uint256 public constant BASE_STAT      = 1;
    uint256 public constant XP_PER_UPGRADE = 10;
    uint256 private constant ITEM_OFFSET   = 1_000_000;

    // ─── Roles ────────────────────────────────────────────────────────────────

    address public gameMaster;

    // ─── Counters ─────────────────────────────────────────────────────────────

    uint256 private _charCounter;
    uint256 private _itemCounter;

    // ─── Structs ──────────────────────────────────────────────────────────────

    struct Character {
        string  name;
        uint256 xp;
        uint256 strength;
        uint256 speed;
        uint256 defence;
    }

    struct Item {
        string  itemType;
        uint256 equippedTo; // 0 = unequipped; non-zero = charId it is attached to
    }

    // ─── State ────────────────────────────────────────────────────────────────

    /// @dev All minted characters keyed by their token ID
    mapping(uint256 => Character) public characters;

    /// @dev All minted items keyed by their token ID
    mapping(uint256 => Item) public items;

    /// @dev True when a token ID belongs to a character (vs an item)
    mapping(uint256 => bool) public isCharacter;

    /// @dev True when a character currently has at least one item equipped.
    ///      Used as a fast check in transferFrom to avoid iterating the array.
    mapping(uint256 => bool) public hasEquippedItems;

    /// @dev Ordered list of item IDs equipped to each character
    mapping(uint256 => uint256[]) private _equippedItems;

    // ─── Custom Errors ────────────────────────────────────────────────────────

    error NotGameMaster();
    error NotCharacterOwner();
    error NotItemOwner();
    error ItemAlreadyEquipped();
    error ItemNotEquippedToCharacter();
    error CharacterHasEquippedItems();
    error InsufficientXP();
    error InvalidStat();
    error StatCapReached();
    error NotACharacter();
    error NotAnItem();

    // ─── Events ───────────────────────────────────────────────────────────────

    event CharacterMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string          name
    );

    event ItemMinted(
        uint256 indexed itemId,
        string          itemType,
        address indexed owner
    );

    event ItemEquipped(
        uint256 indexed charId,
        uint256 indexed itemId,
        address indexed owner
    );

    event ItemUnequipped(
        uint256 indexed charId,
        uint256 indexed itemId,
        address indexed owner
    );

    event XPEarned(
        uint256 indexed charId,
        uint256         amount,
        uint256         newTotal
    );

    event StatUpgraded(
        uint256 indexed charId,
        string          stat,
        uint256         oldValue,
        uint256         newValue
    );

    event GameMasterUpdated(
        address indexed oldGameMaster,
        address indexed newGameMaster
    );

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyGameMaster() {
        if (msg.sender != gameMaster) revert NotGameMaster();
        _;
    }

    modifier onlyCharacterOwner(uint256 charId) {
        if (ownerOf(charId) != msg.sender) revert NotCharacterOwner();
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    /**
     * @param _gameMaster Address authorised to mint items and grant XP.
     *                    Can be rotated by the owner via setGameMaster().
     */
    constructor(address _gameMaster)
        ERC721("HeroForge", "HERO")
        Ownable(msg.sender)
    {
        gameMaster = _gameMaster;
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    /**
     * @notice Replace the game master address.
     *         Call this if the current key is compromised — no redeployment needed.
     * @param _newGameMaster New game master address.
     */
    function setGameMaster(address _newGameMaster) external onlyOwner {
        address old = gameMaster;
        gameMaster  = _newGameMaster;
        emit GameMasterUpdated(old, _newGameMaster);
    }

    // ─── Minting ──────────────────────────────────────────────────────────────

    /**
     * @notice Mint a new character NFT to the caller.
     *         Base stats: strength 1, speed 1, defence 1, XP 0.
     * @param  name Display name for the character.
     * @return tokenId The minted character's token ID.
     */
    function mintCharacter(string calldata name) external returns (uint256) {
        _charCounter++;
        uint256 tokenId = _charCounter;

        // Effects — write all state before any external call
        isCharacter[tokenId] = true;
        characters[tokenId]  = Character({
            name:     name,
            xp:       0,
            strength: BASE_STAT,
            speed:    BASE_STAT,
            defence:  BASE_STAT
        });

        // Interactions — external call last (CEI)
        _safeMint(msg.sender, tokenId);

        emit CharacterMinted(tokenId, msg.sender, name);
        return tokenId;
    }

    /**
     * @notice Mint a new item NFT to a player address. Game master only.
     * @param  to       Recipient of the item.
     * @param  itemType A label describing the item (e.g. "sword", "shield").
     * @return itemId   The minted item's token ID.
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

    // ─── Equip System ─────────────────────────────────────────────────────────

    /**
     * @notice Attach an item to a character you own.
     *         You must own both the character and the item.
     *         An item can only be equipped to one character at a time.
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
     * @notice Remove an equipped item from a character you own.
     *         After removal the item becomes freely transferable again.
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

        // Update the transfer-lock flag once the array is empty
        if (_equippedItems[charId].length == 0) {
            hasEquippedItems[charId] = false;
        }

        emit ItemUnequipped(charId, itemId, msg.sender);
    }

    // ─── XP & Progression ─────────────────────────────────────────────────────

    /**
     * @notice Credit XP to a character. Game master only.
     *         Called after the game verifies a player completed an action.
     * @param charId Token ID of the character to reward.
     * @param amount Amount of XP to add.
     */
    function earnXP(uint256 charId, uint256 amount) external onlyGameMaster {
        // Checks
        if (!isCharacter[charId]) revert NotACharacter();

        // Effects
        characters[charId].xp += amount;

        emit XPEarned(charId, amount, characters[charId].xp);
    }

    /**
     * @notice Spend XP to permanently increment one stat by 1 point.
     *         Costs XP_PER_UPGRADE XP per call.
     *         Valid stats: "strength", "speed", "defence".
     * @param charId Token ID of the character.
     * @param stat   The stat to upgrade ("strength" | "speed" | "defence").
     */
    function spendXP(uint256 charId, string calldata stat)
        external
        onlyCharacterOwner(charId)
    {
        // Checks
        Character storage c = characters[charId];
        if (c.xp < XP_PER_UPGRADE) revert InsufficientXP();

        uint256 oldValue;
        uint256 newValue;

        if (_strEq(stat, "strength")) {
            oldValue = c.strength;
            newValue = oldValue + 1;
            if (newValue > MAX_STAT) revert StatCapReached();
            // Effects — deduct XP then apply upgrade
            c.xp      -= XP_PER_UPGRADE;
            c.strength = newValue;

        } else if (_strEq(stat, "speed")) {
            oldValue = c.speed;
            newValue = oldValue + 1;
            if (newValue > MAX_STAT) revert StatCapReached();
            c.xp   -= XP_PER_UPGRADE;
            c.speed = newValue;

        } else if (_strEq(stat, "defence")) {
            oldValue = c.defence;
            newValue = oldValue + 1;
            if (newValue > MAX_STAT) revert StatCapReached();
            c.xp      -= XP_PER_UPGRADE;
            c.defence  = newValue;

        } else {
            revert InvalidStat();
        }

        emit StatUpgraded(charId, stat, oldValue, newValue);
    }

    // ─── Transfer Lock ────────────────────────────────────────────────────────

    /**
     * @dev Override transferFrom to enforce two transfer locks:
     *      1. A character with any equipped items cannot be transferred.
     *      2. An item that is currently equipped cannot be transferred.
     *      This prevents orphaned equip state across ownership changes.
     */
    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
    {
        if (isCharacter[tokenId] && hasEquippedItems[tokenId]) {
            revert CharacterHasEquippedItems();
        }
        if (!isCharacter[tokenId] && items[tokenId].equippedTo != 0) {
            revert ItemAlreadyEquipped();
        }
        super.transferFrom(from, to, tokenId);
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    /**
     * @notice Return the full Character struct for a given token ID.
     */
    function getCharacter(uint256 charId)
        external
        view
        returns (Character memory)
    {
        if (!isCharacter[charId]) revert NotACharacter();
        return characters[charId];
    }

    /**
     * @notice Return the full Item struct for a given token ID.
     */
    function getItem(uint256 itemId)
        external
        view
        returns (Item memory)
    {
        // Items have a non-empty itemType string when minted
        if (bytes(items[itemId].itemType).length == 0) revert NotAnItem();
        return items[itemId];
    }

    /**
     * @notice Return the list of item IDs currently equipped to a character.
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
     *      Swaps the target with the last element then pops — O(n) but
     *      equipped item counts are expected to be small (< 10).
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
     * @dev Compare two strings via their keccak256 hash.
     *      Used to route stat upgrades without a lookup table.
     */
    function _strEq(string calldata a, string memory b)
        internal
        pure
        returns (bool)
    {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
