# ICT Order Block Comprehensive Research Guide

> Research compilation from web sources (2025-2026) with analysis and recommendations for the EA

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Order Block Mechanics](#order-block-mechanics)
3. [Confirmation Signals](#confirmation-signals)
4. [Entry Models](#entry-models)
5. [Kill Zones](#kill-zones)
6. [PD Arrays & Premium/Discount](#pd-arrays--premiumdiscount)
7. [Advanced Concepts](#advanced-concepts)
8. [EA Gap Analysis](#ea-gap-analysis)

---

## Core Concepts

### What Are Order Blocks?

Order Blocks (OB) are **price zones where institutional traders place large orders**, creating a footprint of smart money activity. These zones represent areas where the market is likely to reverse when price returns to them.

**Key Principle**: Institutions cannot hide their large orders completely. They leave traces in price action through:
- Order Block zones
- Fair Value Gaps (FVG)
- Liquidity sweeps
- Market Structure Shifts

### Smart Money vs Retail Trading

| Aspect | Smart Money (Institutions) | Retail Traders |
|--------|--------------------------|---------------|
| Order Placement | Limit orders at key levels | Market orders |
| Entry Timing | Wait for liquidity sweeps | Enter immediately |
| Timeframe | Higher timeframes (D1, W1) | Lower timeframes |
| View | Supply/Demand imbalances | Directional only |

---

## Order Block Mechanics

### Bullish Order Block

A **bullish order block** is the last bearish candle(s) BEFORE a strong bullish impulse move.

**Identification**:
1. Look for a clear bullish impulse (strong upward movement)
2. Identify the last bearish candle(s) before the impulse
3. Mark the entire candle range as the Order Block zone
4. Wait for price to return to this zone

**Visual**:
```
        ┌─ Impulse (bullish move)
        │
───────┬┴─────────────────────────────────────
       │█ ← Bullish OB (last bearish candle)
        │
```

### Bearish Order Block

A **bearish order block** is the last bullish candle(s) BEFORE a strong bearish impulse move.

**Identification**:
1. Look for a clear bearish impulse (strong downward movement)
2. Identify the last bullish candle(s) before the impulse
3. Mark the entire candle range as the Order Block zone

### Order Block Quality Indicators

| Factor | Strong OB | Weak OB |
|--------|-----------|---------|
| **Wick-to-Body Ratio** | Small wick, large body | Large wick, small body |
| **Impulse Strength** | Strong, decisive move | Weak, hesitant move |
| **Volume** | Above average | Below average |
| **Location** | Near liquidity, PD arrays | Middle of range |
| **Multiple OBs** | Stacked/confluent | Isolated |

### Order Block Validity

- **Active**: Recently formed, high probability
- **Stale**: Older than 20-80 candles (varies by timeframe)
- **Mitigated**: Price has crossed the OB zone

---

## Confirmation Signals

The EA requires multiple confirmations before trading. Here's the ICT framework:

### 1. Liquidity Sweep (MSS - Market Structure Shift)

**Definition**: Price sweeps liquidity zones (stop losses) before creating an Order Block.

**Types**:
- **BSL (Buy Side Liquidity)**: Above swing highs - stop losses for shorts
- **SSL (Sell Side Liquidity)**: Below swing lows - stop losses for longs

**Process**:
1. Price creates swing high/low
2. Stops accumulate at these levels
3. Price sweeps (breaks and closes beyond) these levels
4. New Order Block forms after the sweep

**Why It Matters**: Institutions need to collect liquidity (stop losses) before pushing price in their desired direction.

### 2. Fair Value Gap (FVG)

**Definition**: A 3-candle imbalance where the middle candle's wick doesn't overlap with neighboring candles.

**Bullish FVG**:
```
Candle 1     Candle 2     Candle 3
   │            │            │
   └────┐  ┌───┘      ┌────┘
        │  │          │
        └──┴──────────┘
            ↑
       Gap (FVG)
```

**Bearish FVG**: Inverse - gap to the downside

**FVG Types by Size**:
| Type | Distance | Quality |
|------|----------|---------|
| **Small FVG** | < 25% of OB | Aggressive entry |
| **Medium FVG** | 25-75% of OB | Moderate entry |
| **Large FVG** | > 75% of OB | Conservative entry |

### 3. Market Structure Shift (MSS)

**Definition**: A confirmed break of a previous swing high (bullish) or swing low (bearish).

**Requirements**:
1. Close beyond previous swing high/low
2. Typically requires 2+ candles beyond the level
3. Confirms trend direction change

**vs BOS (Break of Structure)**:
- **MSS**: Early signal, may not break major structure
- **BOS**: Confirmed break of major structure, stronger signal

### 4. Change of Character (CHOCH)

**Definition**: A more subtle shift in market behavior, indicating potential reversal BEFORE a full BOS.

**Identification**:
- Market shows weakness in current trend
- Momentum begins to diverge
- More conservative than MSS

### 5. Top Impulsion (Top Impulse)

**Definition**: The highest point (for sells) or lowest point (for buys) of the move following the Order Block.

**Purpose**: 
- Defines the extent of the bullish/bearish move
- Used for Fibonacci extension targets
- Validates the OB's quality

---

## Entry Models

ICT defines 5 primary entry models, ranked by probability:

### 1. Premium/Discount Entry (Highest Probability)

**Concept**: Trade from discount zones (bullish) or premium zones (bearish) within a defined range.

**Setup**:
1. Identify range (swing high to swing low)
2. Apply Fibonacci retracement (0-100%)
3. **Discount Zone**: 0-33% (buy area)
4. **Midpoint**: 33-66%
5. **Premium Zone**: 66-100% (sell area)

### 2. Liquidity Raid Entry

**Concept**: Enter when price sweeps liquidity and returns to the OB zone.

**Setup**:
1. Wait for BSL/SSL sweep
2. Identify resulting OB
3. Enter when price returns to OB + FVG confirmation

### 3. Fair Value Gap Entry

**Concept**: Enter when price returns to fill an FVG within the OB zone.

**Setup**:
1. Identify OB with FVG
2. Wait for price to return to FVG
3. Enter when price begins to fill the gap

### 4. Order Block Entry (Traditional)

**Concept**: Enter when price reaches the OB zone directly.

**Setup**:
1. Identify valid OB (with confirmations)
2. Wait for price to reach OB zone
3. Enter with limit order at 50% Fibonacci level

### 5. Breaker Block Entry (Lowest Probability)

**Concept**: An OB that has been mitigated becomes a "breaker block" trading in the opposite direction.

**Setup**:
1. Original OB gets mitigated (price crosses through)
2. Wait for price to break through the OB in opposite direction
3. Enter in the NEW direction

---

## Kill Zones

Kill Zones are specific time windows when institutional activity peaks.

### The 4 Primary Kill Zones

| Kill Zone | GMT Hours | Market Context |
|-----------|-----------|----------------|
| **Asia** | 00:00 - 03:00 | Tokyo session, low volatility |
| **London** | 07:00 - 10:00 | European open, high liquidity |
| **New York AM** | 13:00 - 16:00 | US session overlap |
| **London Close** | 16:00 - 18:00 | US open, volatility spike |

### Best Kill Zones for XAUUSD

Based on research, the optimal windows are:
- **London Late Morning**: 11:00 - 14:00 GMT
- **NY Close Session**: 20:00 - 23:00 GMT

These align with the EA's default KZ1 (11-14) and KZ2 (20-23).

### Why Kill Zones Work

1. **Institutional Hours**: Major banks/traders are active
2. **Liquidity**: High volume = better execution
3. **Volatility**: Predictable movement patterns
4. **Low Noise**: Fewer choppy, false moves

---

## PD Arrays & Premium/Discount

### What Are PD Arrays?

PD (Premium/Discount) Arrays define **where smart money is likely to buy or sell** based on market structure.

### The PD Matrix

```
┌─────────────────────────────────────┐
│ PREMIUM ZONE (SELL)                 │
│  ████████████████████████████████    │
│        (Above equilibrium)           │
├─────────────────────────────────────┤
│  EQUILIBRIUM (Midpoint)             │
│         ────────────                 │
├─────────────────────────────────────┤
│  DISCOUNT ZONE (BUY)                │
│        (Below equilibrium)           │
│  ████████████████████████████████    │
└─────────────────────────────────────┘
```

### Fibonacci + PD Arrays

| PD Zone | Fib Retracement | Action |
|---------|-----------------|--------|
| Deep Discount | 0 - 0.236 | Strongest buy signal |
| Discount | 0.236 - 0.382 | Buy signal |
| Midpoint | 0.382 - 0.618 | Neutral |
| Premium | 0.618 - 0.786 | Sell signal |
| Deep Premium | 0.786 - 1.0 | Strongest sell signal |

### Order of Merit (High to Low Probability)

1. **Discount + FVG + OB** (in bullish trend)
2. **Premium + FVG + OB** (in bearish trend)
3. **Discount + OB alone**
4. **Midpoint + OB**
5. **Premium alone**

---

## Advanced Concepts

### Implied Fair Value Gap (IFVG)

An FVG that's "hidden" within a single candle's range. Formed when:
- Candle 1 and 3 overlap in wick
- Candle 2 is completely inside Candle 1's range

### OTE (Optimal Trade Entry)

A Fibonacci-based entry technique:
1. Measure from recent high to low
2. Use 0.618 (62%) as key entry level
3. Combine with OB/FVG for confirmation

### CISD (Change in State of Delivery)

A retest of the MSS break level after initial break:
1. MSS breaks a level
2. Price returns to test the broken level
3. Creates a high-probability entry opportunity

### Breaker Blocks

When an OB is mitigated, it can become a breaker block:
- Original bullish OB becomes bearish resistance
- Original bearish OB becomes bullish support
- Can provide trading opportunities in opposite direction

### Double Breaker Blocks

Two OBs stacked together provide stronger support/resistance zones.

---

## EA Gap Analysis

Based on the comprehensive ICT research above, here's what the current EA covers and what could be added:

### ✅ Currently Implemented

| Feature | Status | ICT Concept |
|---------|--------|-------------|
| Order Block Detection | ✅ Complete | OB identification |
| Liquidity Sweep (MSS) | ✅ Complete | BSL/SSL sweeps |
| Fair Value Gap | ✅ Complete | FVG detection |
| Market Structure | ✅ Complete | Trend alignment |
| Kill Zones | ✅ Complete | Time filtering |
| Fibonacci Levels | ✅ Complete | TP/SL placement |
| Daily Bias | ✅ Complete | Trend filter |
| BreakerBlock | ✅ Complete | Reversal trading |
| Multi-Language | ✅ Complete | Localization |
| Partial Close | ✅ Complete | Risk management |

### ⚠️ Partially Implemented / Could Improve

| Feature | Current State | Recommendation |
|---------|---------------|----------------|
| **PD Arrays** | Disabled by default | Test enabling with new filters |
| **CHOCH Detection** | Not working properly | Needs fix or alternative approach |
| **Implied FVG** | Not implemented | Add detection |
| **Volume Filter** | Basic | Enhance with real volume |

### ❌ Not Implemented (Future Considerations)

| Feature | Priority | Notes |
|---------|----------|-------|
| **HTF Liquidity (as TARGET)** | Medium | Add D1/W1 BSL/SSL as price target |
| **Double OB** | Low | Add quality filter |
| **Equal Highs/Lows (EQH/EQL)** | Low | Advanced liquidity detection |
| **Order Flow Analysis** | Low | Requires tick data |

---

## Expanded Concepts Explained

### Double Order Block (Double OB)

**Definition**: Two or more Order Blocks stacked together within close proximity (typically 20-50 pips), creating a **stronger support/resistance zone**.

**Why It Works**:
- Multiple institutional orders at similar levels = stronger reaction
- Shows "accumulation" or "distribution" at that price
- More likely to hold than a single OB

**Visual**:
```
Price
  │
  │    ┌─────────────┐  OB #2 (newer)
  │    │  Bullish OB │
  │    └─────────────┘
  │    ┌─────────────┐  OB #1 (older)
  │    │  Bullish OB │
  │    └─────────────┘
  └────────────────────
```

**Trading with Double OB**:
- Enter when price reaches either OB zone
- Larger position size (higher confidence)
- Wider stop loss (both OBs must break)

**EA Implementation**:
- Add filter: check if another OB exists within X pips
- Increase stars for Double OB (quality boost)
- Optionally increase lot size

---

### Implied Fair Value Gap (IFVG)

**Definition**: An FVG that's "hidden" within a single candle's body, created when the market gaps but then closes within the previous candle's range.

**vs Regular FVG**:
| Aspect | Regular FVG | Implied FVG |
|--------|-------------|-------------|
| Candles | 3 distinct candles | 1 candle contains it |
| Visual | Clear gap visible | Hidden in body |
| Detection | Wick overlap check | Body overlap check |
| Frequency | Common | Rare |

**Identification Rules**:
1. Candle 2's body is INSIDE Candle 1's body
2. Candle 3's body doesn't overlap Candle 1's wicks
3. Creates "hidden" imbalance that price may still fill

**EA Implementation**:
- Add IFVG detection function
- Check body overlap (not just wick)
- Treat same as regular FVG for entry confirmation

---

### HTF Liquidity as Trade TARGET

**Definition**: Using liquidity zones (BSL/SSL) from higher timeframes (D1, W1, MN) as **price targets** for OB trades.

**Key Distinction**:
- **Current**: Liquidity sweep required BEFORE OB forms (MSS confirmation = ENTRY trigger)
- **HTF Liquidity**: D1/W1 swing highs/lows as **WHERE PRICE WILL GO** after entry = TARGET

**Why Use as Target**:
1. Institutions operate on multiple timeframes
2. D1/W1 liquidity sweeps are more significant than M15
3. Better risk:reward - know exit point in advance

**HTF Liquidity Target Flow**:
| Scenario | Entry | HTF Target |
|----------|-------|-------------|
| Bullish OB | Enter at OB | Target = D1 SSL (below entry) |
| Bearish OB | Enter at OB | Target = D1 BSL (above entry) |

**EA Implementation**:
1. Add function to detect D1/W1 swing highs/lows
2. Store HTF BSL/SSL levels in OB struct
3. Use HTF level as additional TP target or invalidation
4. Add filter: reject trades where HTF target is too close

---

## EA Feature Status (Corrected)

Based on your feedback:

| Feature | Status | Input Parameter |
|---------|--------|-----------------|
| **CISD Entry** | ✅ Already exists | `inpEntryMode = ENUM_EM_CISD` |
| **OTE / Fibonacci Entry** | ✅ Already exists | `fiboEntry` (default 0.65, between 0.618-0.786) |
| **PD Arrays** | ⚠️ Disabled | `enableDPICT = true` to enable |
| **CHOCH** | ❌ Not working | Needs debugging |
| **Double OB** | ❌ Not implemented | Could add as quality filter |
| **Implied FVG** | ❌ Not implemented | Different detection logic |
| **HTF Liquidity** | ❌ Not implemented | Could use as TARGET |

---

### Research Sources

- ICT Trading Organization (icttrading.org)
- Trading Finder (tradingfinder.com)
- Smart Money ICT (smartmoneyict.com)
- Inner Circle Trader (innercircletrader.net)
- LuxAlgo (luxalgo.com)
- FXNX (fxnx.com)
- The Simple ICT (thesimpleict.com)

---

*Document compiled: March 2026*
*Version: 1.0*


---

## Order Flow & CVD Research (Added March 2026)

### The Problem: No Real Volume Data in MT5 Forex

**Key Finding**: MetaTrader 5 does NOT provide real volume data (bid/ask) for forex pairs like XAUUSD. It only provides **tick volume** (number of price updates), which shows activity but NOT direction.

### Available Solutions

| Solution | Type | Availability | Notes |
|----------|------|--------------|-------|
| **Tick Volume** | Activity | Built-in | Shows quantity only, not direction |
| **VSA (Volume Spread Analysis)** | Pattern | Custom indicators | Analyzes volume + spread patterns |
| **ClusterDelta** | Real volume | Paid service | Works for futures, NOT forex |
| **Third-party indicators** | Delta/CVD | Paid/MQL5 | Require special data feeds |

### VSA - The Best Alternative for Forex

**Volume Spread Analysis (VSA)** works without real volume data:

| Pattern | Volume | Spread | Interpretation |
|---------|--------|--------|----------------|
| **High Volume + Narrow Spread** | High | Low | Accumulation (institutions buying) |
| **High Volume + Wide Spread** | High | High | Distribution (institutions selling) |
| **Low Volume + Wide Spread** | Low | High | Weakness (no conviction) |
| **Low Volume + Narrow Spread** | Low | Low | Quiet market |

### Current EA vs Order Flow

The EA already uses concepts similar to VSA:

| VSA Concept | EA Equivalent |
|-------------|---------------|
| Volume analysis | `inpVolumeFilter` (basic) |
| Momentum confirmation | ADX threshold |
| Trend confirmation | MSS/Liquidity sweep |
| Strength confirmation | Top Impulse |

### Recommendation

**For XAUUSD**: The current approach using price action (OB, FVG, MSS) is MORE RELIABLE than trying to use fake volume data. The existing ADX and momentum checks serve a similar purpose to CVD confirmation.

**If you want to add VSA**:
1. Create a simple VSA indicator analyzing spread vs volume
2. Add as pre-entry filter
3. Only works as confirmation, not standalone signal

### Sources
- GrandAlgo: Cumulative Volume Delta Explained
- LuxAlgo: CVD Explained
- MQL5 Market: VSA Volume, Volume Footprint Analysis

