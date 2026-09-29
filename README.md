# HeroForge

> Own your character. Own your progress.

## What It Does

HeroForge is a GameFi smart contract where player characters are ERC-721 NFTs with on-chain progression. Weapons and skins are separate NFTs that can be equipped to or removed from a character. A trusted game-master grants XP after verified gameplay, and players spend that XP to permanently upgrade strength, speed, and defence — all stored on-chain.

## The Problem

In traditional online games, characters, items, and stats live on centralised servers owned by the operator. Players cannot prove ownership — a shutdown, account ban, or policy change can erase everything overnight. HeroForge moves that state on-chain: ownership is provable, progression is permanent, and every item has a verifiable history.

## Design Decisions

- **Single contract** — characters and items are both ERC-721 tokens managed in one contract rather than two separate contracts, keeping the equip relationship simple and atomic.
- **Game master role over open minting** — XP is granted by a trusted address, not self-assigned. This prevents exploitation while remaining rotatable by the owner if the key is compromised.
- **Transfer lock over burn-and-remint** — equipped items block transfer rather than requiring unequip-then-transfer as two separate transactions. This is enforced at the `transferFrom` override level so it cannot be bypassed.
- **Custom errors over string reverts** — cheaper gas on failure paths and easier to catch programmatically in tests and frontends.
- **OpenZeppelin ERC-721** — no custom re-implementation of the standard. Only the logic unique to HeroForge is written from scratch.

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
# Paste full test output here after running npx hardhat test
```

## Deployment

- **Network:** Sepolia Testnet
- **Contract Address:** `— to be added after deployment —`
- **Explorer Link:** `— to be added after deployment —`

### Demonstration Sequence

```
1. deploy           → contract deployed, game master set
2. mintCharacter    → player mints character #1 (str:1 spd:1 def:1 xp:0)
3. mintItem         → game master mints sword #1 to player
4. equipItem        → player equips sword to character #1
5. earnXP           → game master grants 10 XP to character #1
6. spendXP          → player spends 10 XP to upgrade strength (str:1 → str:2)
7. transferFrom     → attempt to transfer character #1 → REVERTS (CharacterHasEquippedItems)
8. unequipItem      → player removes sword from character #1
9. transferFrom     → transfer character #1 to another address → SUCCEEDS
```

## What Is Out of Scope

| Feature | Reason |
|---|---|
| ERC-20 in-game currency | Adds a second token standard outside the defined theme |
| Marketplace / trading contract | Separate contract — over-scoped for this submission |
| On-chain randomness (item rarity) | Requires Chainlink VRF — external dependency not in scope |
| Frontend / dApp UI | Brief explicitly does not require a frontend |
| Breeding, crafting, or combining items | Future extension — separate feature set |
| DAO governance for game master rotation | Adds a voting layer; owner `setGameMaster()` is sufficient |
