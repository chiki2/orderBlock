# BreakerBlock Strategy

## Overview

The BreakerBlock strategy trades Order Blocks (OBs) that have been **broken** and **retested** — turning a traditional counter-trend OB setup into a trend-continuation setup.

## Concept

When an OB is mitigated (price crosses the mid-line), instead of deleting it, the EA waits for the price to **break through** the OB zone. Once broken, the OB becomes a **BreakerBlock** — a new resistance/support zone that can be traded on a retest.

| Original OB | Break Condition | New Trade Direction | Entry Type |
|------------|----------------|--------------------|------------|
| Bullish OB (buy zone) | Price breaks below `lowPrice` | SELL | Retest + momentum |
| Bearish OB (sell zone) | Price breaks above `highPrice` | BUY | Retest + momentum |

## Key Mechanics

### 1. OB → BreakerBlock Transition

When an OB is mitigated (`isMitigated = true`):
- If price continues past the OB extreme → Becomes **BreakerBlock**
- The `isBear` boolean is **flipped** (bullish OB → bearish trade, bearish OB → bullish trade)
- This flip enables existing trailing stop logic to work automatically

### 2. Retest Zone

After becoming a BreakerBlock, the EA waits for price to retest the zone:

| Trade Direction | Retest Zone | Entry Trigger |
|----------------|-------------|---------------|
| SELL (isBear=true) | Between `midline` and `lowPrice` | Candle closes inside zone + momentum |
| BUY (isBear=false) | Between `midline` and `highPrice` | Candle closes inside zone + momentum |

### 3. Entry Conditions

1. OB has become a BreakerBlock (`isBreakerBlock = true`)
2. No existing trade on this OB (`tradeTicket = INVALID_TICKET`)
3. Candle closed inside the retest zone
4. Momentum filter passes (ATR-based)

### 4. Stop Loss & Take Profit

| Trade | Stop Loss | Take Profit |
|-------|-----------|-------------|
| SELL | Above `highPrice` + ATR buffer | -1.27 fib extension from OB |
| BUY | Below `lowPrice` - ATR buffer | +1.27 fib extension from OB |

Fibonacci calculation uses `getFibLevel(isBear, highPrice, lowPrice, -1.27)` — the original OB high/low with the flipped direction.

### 5. Invalidation (Timeout)

If a candle closes on the **opposite side** of the retest zone:
- SELL trade: candle closes above midline → Invalidate
- BUY trade: candle closes below midline → Invalidate

The BreakerBlock is then deleted (`isDone = true`).

## Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `inpEnableBreakerBlock` | false | Enable BreakerBlock strategy |
| `inpBreakerBlockSLBuffer` | 1.0 | SL buffer in ATR multiples |

## Data Fields

New fields added to OB structure:

| Field | Type | Description |
|-------|------|-------------|
| `isBreakerBlock` | bool | OB has become a BreakerBlock |
| `breakerBlockTime` | datetime | When the break occurred |
| `breakerBlockPrice` | double | Price level where break happened |

## Visualization

- BreakerBlock OBs drawn with distinct color (e.g., Orange)
- "BB" label on the OB
- Horizontal line at break point
- Retest zone visualization

## Database

New columns:
- `isBreakerBlock INTEGER`
- `breakerBlockTime TEXT`
- `breakerBlockPrice REAL`

## Flow Diagram

```
┌─────────────┐
│ OB Forms    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ OB Active   │ ← Normal OB trading
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ OB Mitigated   │ (price crosses mid-line)
└──────┬──────────┘
       │
       ▼
┌───────────────────┐
│ Wait for Break   │ (price passes OB extreme)
└──────┬────────────┘
       │
       ▼
┌─────────────────────┐
│ Become BreakerBlock │ ← isBear flipped, isBreakerBlock = true
└──────┬──────────────┘
       │
       ▼
┌───────────────────┐
│ Wait for Retest  │ (candle close in zone)
└──────┬────────────┘
       │
       ▼
┌───────────────────┐
│ Entry Triggered   │ ← momentum OK + close in zone
└───────────────────┘
```

## Example

1. **Bullish OB** forms at 2000-2010 (buy zone)
2. Price enters OB, crosses midline at 2005 → OB is mitigated
3. Price continues down, breaks below 2000 → OB becomes **BreakerBlock**
4. `isBear` flips to `true` (now bearish trade)
5. Price retraces up to 2003-2007 zone (between mid and low)
6. Candle closes at 2005 inside zone + momentum OK
7. **SELL** entry at fib -1.27 level
8. SL above 2010 + ATR buffer
9. TP at -1.27 extension below 2000

---

*Document created for OrderBlock EA v1.60+*
