// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  HeroForgeStorage
 * @notice Base contract — holds all shared state, structs, errors, events,
 *         constants, and access-control modifiers used by every layer above.
 * Inheritance chain
 * ─────────────────
 *   HeroForgeStorage
 *     └── HeroForgeCharacters
 *           └── HeroForgeItems
 *                 └── HeroForgeProgression
 *                       └── HeroForge  ← only this is deployed
 */
abstract contract HeroForgeStorage is ERC721, Ownable {

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant MAX_STAT       = 100;
    uint256 public constant BASE_STAT      = 1;
    uint256 public constant XP_PER_UPGRADE = 10;

    /// @dev Items start at this offset so their IDs never collide with characters.
    uint256 internal constant ITEM_OFFSET = 1_000_000;

    // ─── Roles ────────────────────────────────────────────────────────────────

    /// @notice Address authorised to mint items and grant XP.
    address public gameMaster;

    // ─── Counters ─────────────────────────────────────────────────────────────

    uint256 internal _charCounter;
    uint256 internal _itemCounter;

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
        uint256 equippedTo; // 0 = unequipped; otherwise = charId it is attached to
    }

    // ─── State ────────────────────────────────────────────────────────────────

    /// @dev Character data keyed by token ID.
    mapping(uint256 => Character) public characters;

    /// @dev Item data keyed by token ID.
    mapping(uint256 => Item) public items;

    /// @dev True when a token ID belongs to a character (not an item).
    mapping(uint256 => bool) public isCharacter;

    /// @dev True when a character has at least one item equipped.
    ///      Used as a fast gate in transferFrom — avoids iterating the array.
    mapping(uint256 => bool) public hasEquippedItems;

    /// @dev Ordered list of item IDs currently equipped to each character.
    mapping(uint256 => uint256[]) internal _equippedItems;

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
}
