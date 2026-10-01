# HeroForge — Specification

> Own your character. Own your progress.

**Author:** Rahul A
**Contract:** `HeroForge.sol`  
**Network:** Sepolia Testnet  
**Framework:** Hardhat + OpenZeppelin  

---

## Overview

HeroForge is a GameFi smart contract where player characters are ERC-721 NFTs with on-chain progression. Weapons and skins are separate NFTs that can be equipped to or removed from a character. A trusted game-master address grants XP after verified gameplay; players spend that XP to permanently upgrade strength, speed, and defence. A character carrying equipped items is transfer-locked until those items are removed. Every action emits an on-chain event, forming a permanent provenance trail for every asset.

---

## 1. State — What the Contract Must Store

| Variable / Mapping | Purpose |
|---|---|
| `address public gameMaster` | The trusted account authorised to grant XP and mint items |
| `uint256 private _charCounter` | Auto-incrementing ID for each new character token |
| `uint256 private _itemCounter` | Auto-incrementing ID for each new item token |
| `mapping(uint256 => Character) public characters` | Stores stats (str, spd, def), XP balance, and name per character tokenId |
| `mapping(uint256 => Item) public items` | Stores item type and equipped-to character ID (0 = unequipped) per item tokenId |
| `mapping(uint256 => uint256[]) public equippedItems` | Lists all item IDs currently equipped to a character |
| `mapping(uint256 => bool) public hasEquippedItems` | Quick flag used to block transfers when a character has items equipped |

### Structs

```solidity
struct Character {
    string name;
    uint256 xp;
    uint256 strength;
    uint256 speed;
    uint256 defence;
}

struct Item {
    string itemType;
    uint256 equippedTo; // 0 = unequipped
}
```

---

## 2. Functions — Name, Visibility, and Purpose

| Function | Visibility | Purpose |
|---|---|---|
| `mintCharacter(string name)` | external | Any player mints a new character NFT with base stats (str:1, spd:1, def:1) and 0 XP |
| `mintItem(address to, string itemType)` | external | Game master mints a weapon or skin NFT to a player address |
| `equipItem(uint256 charId, uint256 itemId)` | external | Character owner attaches an item they own to their character |
| `unequipItem(uint256 charId, uint256 itemId)` | external | Character owner removes an equipped item from their character |
| `earnXP(uint256 charId, uint256 amount)` | external | Game master credits XP to a character after a verified gameplay action |
| `spendXP(uint256 charId, uint256 amount, string stat)` | external | Character owner spends XP to permanently increment a chosen stat |
| `getCharacter(uint256 charId)` | view / external | Returns the full Character struct for a given token ID |
| `getItem(uint256 itemId)` | view / external | Returns the full Item struct for a given item ID |
| `getEquippedItems(uint256 charId)` | view / external | Returns the array of item IDs currently equipped to a character |
| `transferFrom (override)` | public | Reverts with `CharacterHasEquippedItems` if the character has any equipped items |

---

## 3. Access Control — Who May Call What

| Caller | Permitted functions |
|---|---|
| Anyone | `mintCharacter()` — players mint their own characters |
| Item owner only | `equipItem()` — must own both the character and the item |
| Character owner only | `unequipItem()`, `spendXP()`, transfer (only when no items equipped) |
| Game master only | `mintItem()`, `earnXP()` |
| Contract owner only | `setGameMaster()` — rotate the game master address if compromised |
| Nobody | Direct stat manipulation — stats only change through `spendXP()` |

---

## 4. Events — What Gets Reported On-Chain

| Event | When it fires |
|---|---|
| `CharacterMinted(uint256 indexed tokenId, address indexed owner, string name)` | On every successful `mintCharacter()` |
| `ItemMinted(uint256 indexed itemId, string itemType, address indexed owner)` | On every successful `mintItem()` |
| `ItemEquipped(uint256 indexed charId, uint256 indexed itemId, address owner)` | When a player equips an item to their character |
| `ItemUnequipped(uint256 indexed charId, uint256 indexed itemId, address owner)` | When a player removes an item from their character |
| `XPEarned(uint256 indexed charId, uint256 amount, uint256 newTotal)` | After game master grants XP to a character |
| `StatUpgraded(uint256 indexed charId, string stat, uint256 oldValue, uint256 newValue)` | After a player spends XP to upgrade a stat |

---

## 5. Invariants — What Must Never Be Allowed to Happen

| Must never happen | Why it matters |
|---|---|
| A character with equipped items is transferred | Equipped items would orphan — the new owner controls the character but not the items |
| An address that is not the game master calls `earnXP()` | Unlimited free XP would make the progression system meaningless and exploitable |
| A player equips an item they do not own | They would control an asset on a character without being the rightful owner |
| An item is equipped to two characters simultaneously | A single item ID can only have one `equippedTo` value — dual-equip is a data integrity violation |
| XP balance underflows below zero | `spendXP` must revert if the player has insufficient XP |
| A stat is upgraded beyond its defined cap | Uncapped stats break game balance — `require(newValue <= MAX_STAT)` guards every upgrade |
| An unapproved address calls `mintItem()` | Items minted outside the game master flow are unverified and pollute the item registry |
