# HeroForge

## Project Scope Document

**Author:** Rahul A· **Contract:** `HeroForge.sol` · **Network:** Sepolia · **Framework:** Hardhat + OpenZeppelin

---

## 1. What HeroForge Is

HeroForge is a GameFi smart contract where player characters are ERC-721 NFTs with on-chain progression. Weapons and skins are separate NFTs that can be equipped to or removed from a character. A trusted game-master address grants XP after verified gameplay; players spend that XP to permanently upgrade strength, speed, and defence. A character carrying equipped items is transfer-locked until those items are removed. Every action emits an on-chain event — forming a permanent provenance trail for every asset.

**Theme from Final Project Topic Catalogue:** Digital Assets (ownership that grants a right) merged with Loyalty Points (earn and redeem under enforced rules).

---

## 2. The Problem Being Solved

In traditional online games, characters, items, and progression stats live on centralised servers owned by the operator. Players cannot prove ownership — a shutdown, ban, or policy change can erase everything. There is no public record of what was earned, when, or by whom. HeroForge moves that state on-chain: ownership is provable, progression is permanent, and every item has a verifiable history.

---

## 3. Feature Scope — In and Out

Each feature is listed with its in/out decision and the reason.

| Feature | Status | Reason |
| :--- | :---: | :--- |
| ERC-721 character NFT with base stats | ✓ In | Core feature — `mintCharacter()` is the entry point of the whole system |
| ERC-721 item NFTs (weapons / skins) | ✓ In | Core feature — items are the second asset type the contract manages |
| `equipItem()` and `unequipItem()` | ✓ In | Core interaction — the main player action this contract is built around |
| Transfer lock on characters with equipped items | ✓ In | Core invariant — prevents orphaned item state across ownership change |
| Game master role and `earnXP()` | ✓ In | Required — XP source must be access-controlled, not self-assigned by players |
| `spendXP()` and permanent stat upgrades | ✓ In | Core loop — earn XP then spend to upgrade strength / speed / defence |
| Custom errors (not string reverts) | ✓ In | Explicit requirement in project brief — no string revert messages |
| Events on every meaningful state change | ✓ In | Explicit requirement — provides provenance trail for every asset |
| OpenZeppelin ERC-721 base + Ownable | ✓ In | Explicit requirement — do not re-implement any standard |
| Checks-Effects-Interactions pattern | ✓ In | Explicit requirement — must be respected across all state changes |
| Access control on all privileged functions | ✓ In | First thing checked in code review — every privileged path guarded |
| Minimum 8 tests, at least 4 failure paths | ✓ In | Explicit requirement — one test per invariant from spec |
| Sepolia deployment via script + verified | ✓ In | Explicit requirement — automated deployment and explorer verification |
| `README.md` + `SPEC.md` + demo sequence | ✓ In | Explicit repository structure requirement |
| ERC-20 in-game currency / token economy | ✗ Future | Adds a second token standard outside the defined theme scope |
| Marketplace or trading contract | ✗ Future | Separate contract — over-scoped for a single session submission |
| On-chain randomness for item rarity | ✗ Future | Requires Chainlink VRF — external dependency outside scope |
| Frontend / dApp UI | ✗ Future | Brief explicitly states no frontend is required |
| Breeding, crafting, or combining items | ✗ Future | Separate feature set — noted as future extension only |
| DAO governance for game master rotation | ✗ Future | Adds a voting layer; owner can rotate game master via `setGameMaster()` |

---

## 4. Requirements Checklist — Mapped to HeroForge

### Smart Contracts

- **✓ Substantial contracts**  
  `HeroForge.sol` — single unified contract architecture (modularized via base storage and components): character NFTs, item NFTs, equip logic, XP, stat upgrades. All game logic is custom-built on top of OpenZeppelin standard bases.

- **✓ Access control on every privileged function**  
  `earnXP()` and `mintItem()` → `onlyGameMaster`. `setGameMaster()` → `onlyOwner`. `equipItem()` → caller must own both character and item. `unequipItem()` and `spendXP()` → caller must own the character.

- **✓ Checks-Effects-Interactions wherever state changes**  
  No ETH is held. All state changes follow Checks (custom error reverts) → Effects (mapping updates) → Interactions (events emitted, no unsafe external calls). `transferFrom` override checks `hasEquippedItems` before any transfer proceeds.

- **✓ Custom errors, not string messages**  
  Defined: `NotGameMaster`, `NotCharacterOwner`, `NotItemOwner`, `ItemAlreadyEquipped`, `CharacterHasEquippedItems`, `InsufficientXP`, `InvalidStat`, `StatCapReached`.

- **✓ Events on every meaningful state change**  
  `CharacterMinted`, `ItemMinted`, `ItemEquipped`, `ItemUnequipped`, `XPEarned`, `StatUpgraded` — all indexed for off-chain filtering.

- **✓ OpenZeppelin for standard implementations**  
  `ERC721` from `@openzeppelin/contracts`. `Ownable` for contract owner access control.

---

### Tests — 12 Comprehensive Test Cases

| Test | Description | Type |
| :--- | :--- | :--- |
| **T-01** | `mintCharacter()` — mints token to caller with correct base stats (str:1, spd:1, def:1) | Success |
| **T-02** | `mintItem()` — game master mints item to player address | Success |
| **T-03** | `equipItem()` — owner equips item, `hasEquippedItems` becomes true | Success |
| **T-04** | `unequipItem()` — owner removes item, transfer lock released | Success |
| **T-05** | `earnXP()` + `spendXP()` — XP granted and stat increments correctly | Success |
| **T-06** | `transferFrom` reverts when character has equipped items | Failure / Invariant |
| **T-07** | `earnXP()` reverts when caller is not game master | Failure / Access |
| **T-08** | `mintItem()` reverts when caller is not game master | Failure / Access |
| **T-09** | `equipItem()` reverts when caller does not own the item | Failure / Access |
| **T-10** | `spendXP()` reverts when XP balance is insufficient | Failure / Invariant |
| **T-11** | `spendXP()` reverts when stat is already at cap | Failure / Invariant |
| **T-12** | `equipItem()` reverts when item is already equipped to another character | Failure / Invariant |

---

### Deployment & Verification

- **✓ Deployed to Sepolia using a script**  
  `scripts/deploy.js` — Hardhat + ethers. Configures game master address, waits for block confirmations, and verifies contract.

- **✓ Contract verified on block explorer**  
  Verified and readable on Sepolia Etherscan.

- **✓ Documented demonstration sequence in README**  
  Deploy → `mintCharacter` → `mintItem` → `equipItem` → `earnXP` → `spendXP` → transfer attempt (reverts) → `unequipItem` → transfer (succeeds).

---

## 5. Repository Layout

| Path | Contents / Purpose |
| :--- | :--- |
| **`README.md`** | What it does, problem, design decisions, security, commands, test output, deployment link, out of scope |
| **`SPEC.md`** | Full specification — state variables, functions, access control, events, invariants |
| **`SCOPE.md`** | Project scope document — in/out features, requirements checklist, build order |
| **`.env.example`** | `PRIVATE_KEY`, `SEPOLIA_RPC_URL`, `ETHERSCAN_API_KEY` — placeholders only |
| **`.gitignore`** | `node_modules/`, `.env`, `artifacts/`, `cache/` — protects secrets |
| **`package.json`** | Hardhat, `@openzeppelin/contracts`, `dotenv`, `@nomicfoundation/hardhat-toolbox` |
| **`hardhat.config.js`** | Sepolia network config, Solidity 0.8.28, Etherscan verifier config |
| **`contracts/HeroForge.sol`** | Main entry contract |
| **`contracts/base/`** | Modular base contracts (`HeroForgeStorage.sol`, `HeroForgeCharacters.sol`, `HeroForgeItems.sol`, `HeroForgeProgression.sol`) |
| **`test/HeroForge.test.js`** | 12 automated unit tests — all success and failure paths |
| **`scripts/deploy.js`** | Automated deploy and verification script |

---

## 6. Security Considerations

| Risk | Mitigation |
| :--- | :--- |
| **Unauthorised XP granting** | `earnXP()` gated by `onlyGameMaster` — single trusted address, rotatable by owner |
| **Orphaned items on character transfer** | `transferFrom` override reverts with `CharacterHasEquippedItems` if any item is equipped |
| **Same item equipped to two characters** | `equipItem()` checks `items[itemId].equippedTo == 0` before proceeding |
| **XP underflow on spend** | `InsufficientXP` custom error thrown if `xp < amount`; Solidity 0.8+ also catches arithmetic underflow |
| **Stat overflow beyond cap** | `StatCapReached` error thrown if `newValue > MAX_STAT` before state is written |
| **Game master key compromise** | `setGameMaster()` lets owner rotate the address without redeploying the contract |
| **No Ether held in contract** | Contract holds no ETH — no withdrawal function, no reentrancy surface |

---

## 7. Recommended Build Order

- **Step 1 — Scaffold repo:** `hardhat init`, install OpenZeppelin, create folder structure, `.env.example`, `.gitignore`
- **Step 2 — Write SPEC.md:** Define full state, functions, custom errors, events, and invariants
- **Step 3 — Write SCOPE.md:** Establish feature boundaries, requirements mapping, and security model
- **Step 4 — HeroForge.sol & Base Contracts:** Implement storage, structs, state variables, custom errors, ERC-721 base, `mintCharacter()`
- **Step 5 — Add item system:** `mintItem()`, `equipItem()`, `unequipItem()`, `transferFrom` override
- **Step 6 — Add XP & progression:** `earnXP()`, `spendXP()` with stat cap checks
- **Step 7 — Write all 12 tests:** Run `npx hardhat test` until all 12 tests pass
- **Step 8 — scripts/deploy.js:** Deploy to Sepolia, verify contract on Etherscan, log address
- **Step 9 — Finalize README.md:** Include test output, contract address, demo sequence, and acknowledgments
