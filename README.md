# HeroForge

> Own your character. Own your progress.

## What It Does

HeroForge is a GameFi smart contract where player characters are ERC-721 NFTs with on-chain progression. Weapons and skins are separate NFTs that can be equipped to or removed from a character. A trusted game-master grants XP after verified gameplay, and players spend that XP to permanently upgrade strength, speed, and defence — all stored on-chain. A character carrying equipped items is transfer-locked until those items are removed, and every action emits an on-chain event that forms a permanent provenance trail for every asset.

## The Problem

In traditional online games, characters, items, and stats live on centralised servers owned by the operator. Players cannot prove ownership — a shutdown, account ban, or policy change can erase everything overnight. HeroForge moves that state on-chain: ownership is provable, progression is permanent, and every item has a verifiable history.

## Design Decisions

- **Single contract** — characters and items are both ERC-721 tokens managed in one contract rather than two separate contracts, keeping the equip relationship simple and atomic.
- **Game master role over open minting** — XP is granted only by a trusted game-master address, not self-assigned by players. This prevents exploitation while remaining rotatable by the contract owner via `setGameMaster()` if the key is ever compromised — no redeployment needed.
- **Transfer lock over burn-and-remint** — Equipped items block transfer at the `transferFrom` level rather than requiring a separate unequip step before every transfer. The override catches both directions — a character with items equipped cannot move, and an equipped item cannot be stripped away from its character either.
- **Custom errors over string reverts** — Every revert uses a named custom error (`NotGameMaster`, `InsufficientXP`, etc.) rather than a string message. This is cheaper on gas for the caller and makes failure reasons unambiguous in tests and frontends.
- **OpenZeppelin ERC-721 and Ownable** — No custom re-implementation of any standard. The ERC-721 base and Ownable come from `@openzeppelin/contracts`. Only the logic unique to HeroForge is written from scratch.

## Security Considerations

| Risk | Mitigation |
|---|---|
| Unauthorised XP granting | `earnXP()` gated by `onlyGameMaster` — rotatable by owner via `setGameMaster()` |
| Orphaned items on transfer | `transferFrom` override reverts with `CharacterHasEquippedItems` |
| Same item on two characters | `equipItem()` checks `items[itemId].equippedTo == 0` before equipping |
| XP underflow | `InsufficientXP` error thrown before state write; Solidity 0.8 also catches underflow |
| Stat overflow beyond cap | `StatCapReached` error thrown if `newValue > MAX_STAT` |
| Game master key compromise | `setGameMaster()` lets owner rotate address without redeploying |
| No Ether in contract | Contract holds no ETH — no withdrawal function, no reentrancy surface |

## How to Run

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd heroforge

# 2. Install dependencies
npm install

# 3. Copy env file and fill in your values
cp .env.example .env

# 4. Compile
npx hardhat compile

# 5. Run tests
npx hardhat test

# 6. Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia
```

## Test Output

```
  HeroForge
    T-01 mintCharacter — success
      ✔ mints a character NFT to the caller with correct base stats and zero XP (1075ms)
    T-02 mintItem — success
      ✔ game master mints an item NFT to a player with correct type and zero equippedTo (41ms)
    T-03 equipItem — success
      ✔ owner equips item to their character; hasEquippedItems becomes true (42ms)
    T-04 unequipItem — success
      ✔ owner removes item; hasEquippedItems clears; character becomes transferable (60ms)
    T-05 earnXP + spendXP — success
      ✔ game master grants XP; player spends it to permanently upgrade a stat (74ms)
    T-06 transferFrom — reverts when character has equipped items [Inv-1]
      ✔ reverts with CharacterHasEquippedItems; item cannot be stripped via transfer either (41ms)
    T-07 earnXP — reverts for non-game-master caller [Inv-2]
      ✔ reverts with NotGameMaster when an attacker calls earnXP
    T-08 mintItem — reverts for non-game-master caller [Inv-3]
      ✔ reverts with NotGameMaster when an attacker tries to mint an item
    T-09 equipItem — reverts when caller does not own the item [Inv-4]
      ✔ reverts with NotItemOwner when attacker tries to equip another player's item
    T-10 spendXP — reverts when XP balance is insufficient [Inv-6]
      ✔ reverts with InsufficientXP when character has 0 XP
    T-11 spendXP — reverts when stat is at MAX_STAT (100) [Inv-7]
      ✔ reverts with StatCapReached after strength reaches 100 (192ms)
    T-12 equipItem — reverts when item is already equipped [Inv-5]
      ✔ reverts with ItemAlreadyEquipped when same item is equipped to a second character
    T-13 setGameMaster — reverts for non-owner [privileged]
      ✔ reverts with OwnableUnauthorizedAccount when attacker tries to rotate game master
 
 
  13 passing (2s)
```

## Deployment

- **Network:** Sepolia Testnet
- **Contract Address:** `0xa574CbE7b3CD4e082D518141E64AF3e795dA487A`
- **Explorer:** https://sepolia.etherscan.io/address/0xa574CbE7b3CD4e082D518141E64AF3e795dA487A#code

### Demonstration Sequence

```
1. mintCharacter("Thorin")
   → Mints character token #1 to caller
   → Stats: strength 1, speed 1, defence 1, XP 0
   → Emits: CharacterMinted(1, callerAddress, "Thorin")
 
2. mintItem(playerAddress, "sword")            ← game master only
   → Mints item token #1000001 to player
   → Emits: ItemMinted(1000001, "sword", playerAddress)
 
3. equipItem(1, 1000001)
   → Attaches sword to character #1
   → hasEquippedItems[1] = true
   → Emits: ItemEquipped(1, 1000001, playerAddress)
 
4. transferFrom(player, anyone, 1)             ← attempt while equipped
   → REVERTS: CharacterHasEquippedItems
   → Character cannot move while carrying items
 
5. earnXP(1, 10)                               ← game master only
   → character[1].xp = 10
   → Emits: XPEarned(1, 10, 10)
 
6. spendXP(1, "strength")
   → Deducts 10 XP, strength: 1 → 2
   → Emits: StatUpgraded(1, "strength", 1, 2)
 
7. unequipItem(1, 1000001)
   → Removes sword from character #1
   → hasEquippedItems[1] = false
   → Emits: ItemUnequipped(1, 1000001, playerAddress)
 
8. transferFrom(player, newOwner, 1)           ← now succeeds
   → Character transferred cleanly
   → New owner inherits all on-chain stats and XP
```
 
## What Is Out of Scope
 
| Feature | Reason |
|---|---|
| ERC-20 in-game currency | Adds a second token standard and cross-contract calls — outside the defined theme scope |
| Marketplace / trading contract | Separate contract — over-scoped for this submission |
| On-chain randomness for item rarity | Requires Chainlink VRF — external dependency not in scope |
| Frontend / dApp UI | Brief explicitly does not require a frontend |
| Breeding, crafting, or combining items | Future extension — separate feature set |
| DAO governance for game master rotation | Adds a voting layer; `setGameMaster()` via owner is sufficient |
| Multi-game portability | Cross-contract item use requires a registry pattern — future work |
 