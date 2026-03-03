# Gold ICT Order Block Expert

Manuel v1.60 (2026-03-03)

## [Trading with ICT Order Block](https://www.mql5.com/en/market/product/143851)

The **order block trading strategy** is based on the concept of smart money, focusing on identifying specific zones where institutional traders previously executed their orders. Once we have successfully identified these zones, we patiently wait for the price to revisit these levels.

If you want to get more familiar with ICT Order Block concepts, please read the full article here: https://icttrading.org/order-block-in-forex/

I have tested this strategy for a long time and can confirm it works. Today this Expert Advisor achieves **79% win rate over 2022–2025** (verified on real ticks, out-of-sample), which I consider reliable and consistent across market conditions.

I constantly think about improving this rate while keeping maximum profit as the goal. Each update brings fixes, new features, and validated improvements.

Here is the full guide to understand and master this EA. Please give me feedback to improve it!

---

## Mechanism of this Expert Advisor

Based on the ICT Order Block strategy, the EA detects Order Blocks and waits for triggers before placing a trade.

**Chronology of a trade:**

1. **Detect a bullish or bearish Order Block.** To be valid, it must:
   1. Have liquidity swept before it starts (indicated by a smile icon if confirmed)
   2. Have an imbalance (Fair Value Gap) — more info: https://icttrading.org/decoding-the-fair-value-gap-fvg-trading/
   3. Be aligned with the trend (W1 macro trend, D1 daily trend, H1 trend)
   4. Break a previous market structure (BOS) — more info: https://www.mindmathmoney.com/articles/break-of-structure-bos-and-change-of-character-choch-trading-strategy

2. **Before the price returns to the zone**, we look at price levels:
   1. If price reaches the first target level (1.127 Fibonacci), the Order Block earns 3 stars — the minimum to consider a trade (but does not guarantee entry)
   2. Further Fibonacci levels add stars and may upgrade the take profit target depending on momentum
   3. If price crosses the mitigated line (middle of the OB, dashed line) before entry, the OB is invalidated

3. **When price returns to the zone (rehearsal)**, we wait for:
   1. Price to cross the 0.5 Fibonacci level (default entry price)
   2. Price not to cross the mitigated line
   3. A **limit order** (BuyLimit or SellLimit) is placed at the entry level
   4. If price fills the limit order, the trade is active. If price goes the wrong way, the order expires.

4. **Once the trade is active:**
   1. First take profit is at 1.127 Fibonacci (default). If **Enable Max Gain** is on, the EA continues to steps 3–5.
   2. Stop loss is ATR-based with a configurable multiplier
   3. If price reaches the 1.0 Fibonacci trigger and ADX is above threshold, take profit upgrades to 1.618
      - If **Enable Protection** is on, stop loss moves to breakeven
   4. If price reaches the 1.4 Fibonacci trigger and ADX is above threshold, take profit upgrades to 2.3812
   5. If price reaches the 2.0 Fibonacci trigger and ADX is above threshold, trailing stop activates and take profit is removed

---

## Opening Times — Kill Zone Filter

The EA only trades during two specific Kill Zone windows, defined in **GMT time** (no timezone configuration needed):

| Session | GMT Hours | Market Context |
|---|---|---|
| **KZ1** | 11:00 – 14:00 | London late morning / Pre-NY open |
| **KZ2** | 20:00 – 23:00 | NY close session |

These windows were optimized on 2022–2025 real-tick data and represent the highest-probability periods for XAUUSD Order Block setups. Trading outside these hours is automatically filtered out.

You can disable or change the KZ windows in the **ICT Kill Zone Filter** settings, or use a **Risk Profile** preset that configures them automatically.

---

## Risk Profile (New in v1.60)

The **inpRiskProfile** input provides one-click configuration of all filter settings. Instead of tuning 6+ individual inputs, simply select a profile:

| Profile | KZ | Daily Bias | Macro Trend | D1 Trend | H4 Trend |
|---|---|---|---|---|---|
| Very Aggressive | Off | ✗ | ✗ | ✗ | ✗ |
| Aggressive | 8–17 + 18–23 UTC | ✗ | ✓ | ✗ | ✗ |
| Balanced | 9–15 + 20–23 UTC | ✓ | ✓ | ✗ | ✗ |
| **Conservative** *(default)* | 11–14 + 20–23 UTC | ✓ | ✓ | ✓ | ✗ |
| Very Conservative | 11–14 + 20–23 UTC | ✓ | ✓ | ✓ | ✓ |
| Custom | From inputs | From inputs | From inputs | From inputs | From inputs |

Select **Custom** if you want to control each filter individually via the inputs below.

---

## Parameters: Explanation & Impact

### 1. General Settings

| Parameter | Default | Description |
|---|---|---|
| **inpRiskProfile** | Conservative | One-click filter preset. Use Custom to control filters individually. |
| **uniqueMagicNumber** | 1234555 | Unique identifier linking trades to this EA instance. Must be different if running multiple EAs simultaneously. |
| **maxWickRatio** | 1.6 | Maximum ratio of wick to body size on the OB candle. Filters weak, uncertain Order Blocks. |
| **minBodySize** | 40 | Minimum body size (in points) of the OB candle. Filters small, low-momentum candles. |
| **minImBalanced** | 40 | Minimum size of the Fair Value Gap imbalance. A weak FVG indicates a weak Order Block. |
| **tolerance** | 50 | Tolerance in points for wick deviation — filters noise at zone boundaries. |
| **maxGain** | true | If true, the EA will upgrade the take profit target when momentum confirms (Fibonacci cascade). |
| **outdatedOB** | 80 | Maximum age of an Order Block in bars. OBs older than this are discarded. |
| **inpHistoricalScanBars** | 30 | Number of historical bars to scan for Order Blocks on startup. |

---

### 2. Trading Settings

| Parameter | Default | Description |
|---|---|---|
| **inpMarketMode** | 3 | Which market to trade: 0=All, 1=Forex, 2=Metals, 3=Gold (XAUUSD optimized) |
| **forbidMondayFriday** | false | If true, no trades on Monday or Friday. These days can be volatile around the open/close. |
| **ADX_Period** | 9 | Period for ADX calculation. Shorter = more reactive. |
| **ADX_Threshold** | 25.0 | Minimum ADX value to consider momentum strong enough for TP upgrade. |
| **ADX_Max** | 60.0 | Maximum ADX. Above this, market is too aggressive and no trade is taken. |
| **ATR_Period** | 18 | Period for ATR (Average True Range). Used for stop loss and trailing stop calculation. |
| **ATR_multiplier** | 2.0 | Stop loss = ATR × this multiplier. Higher = wider stop, fewer SL hits. |
| **ATR_max** | 8.2 | Maximum ATR value. If ATR exceeds this, market is too volatile and no trade is taken. |
| **MitigatedMode** | 1 | When to consider an OB mitigated: 0=Full close, 1=Middle line crossed, 2=Zone touched |
| **inpMSSRequireFVG** | true | Require a Fair Value Gap confirmation before triggering the Market Structure Shift entry. |
| **inpAllowMitigatedReentry** | false | Allow re-entry into a previously mitigated Order Block zone. |
| **typeOfTrade** | 2 (Both) | 0=Buy only, 1=Sell only, 2=Both. For XAUUSD in strong bull trends, Buy only is common. |
| **typeofOrder** | 1 (Limit) | Order type: 1=Limit orders (BuyLimit/SellLimit). Limit orders give better fills. |
| **StopLossStartMode** | 0 | How to set initial SL: 0=ATR-based, 1=OB high/low, 2=Fibonacci level |
| **fiboStopLoss** | -0.1 | Fibonacci level for stop loss placement (used when StopLossStartMode=2). |
| **inpEntryMode** | 0 | 0=Standard (limit at 0.5 Fibo), 1=AUTO (waits for LTF MSS confirmation before entry) |
| **fiboEntry** | 0.65 | Fibonacci level for entry price. Default 0.65 = 65% into the OB zone. |
| **TPModeInpTP1** | 0 | Take profit mode for first target. |
| **fibo1rstTP** | 1.27 | First take profit Fibonacci level. |
| **fiboProtectTrigger** | 0.4 | If TP is 1.618 and price crosses this level, stop loss moves to breakeven. |
| **fibo1rstTrigger** | 1.0 | If price crosses this level and ADX is strong, TP upgrades to 1.618. |
| **fibo2ndTP** | 1.618 | Second take profit Fibonacci level. |
| **fibo2ndTrigger** | 1.4 | If price crosses this level and ADX is strong, TP upgrades to 2.3812. |
| **fibo3rdTP** | 2.3812 | Third (final) take profit Fibonacci level. |
| **fibo3rdTrigger** | 2.0 | If price crosses this level and ADX is strong, trailing stop activates and TP is removed. |
| **fiboExtended** | 8.0 | If price reaches this level, the OB is considered over-extended and invalid. |
| **enableDPICT** | false | Enable Premium/Discount ICT zone filter. Currently disabled — testing showed it removes more winners than losers. |
| **inpMaxSpread** | 0 | Maximum allowed spread in points. 0 = no limit. **Recommended for live: set to 30–50 for XAUUSD** to avoid entries during spread spikes. |
| **inpMaxPositionsPerDir** | 0 | Maximum simultaneous positions per direction. 0 = no limit. |
| **inpDailyBiasEnabled** | true | Only take trades in the direction of the daily open price bias (price above/below daily open). |
| **inpMinRR** | 0.0 | Minimum required Risk:Reward ratio. 0 = no filter. |
| **inpMaxSLPoints** | 0 | Maximum stop loss distance in points. 0 = no limit. |
| **inpMinSLPoints** | 0 | Minimum stop loss distance in points. 0 = no limit. |
| **inpVolumeFilter** | false | Require OB candle volume to exceed recent average × multiplier. |
| **inpVolumeMinMult** | 1.2 | Minimum volume multiplier threshold (used when inpVolumeFilter = true). |

---

### 3. Trailing Stop

| Parameter | Default | Description |
|---|---|---|
| **enableTrailingStop** | false | Enable trailing stop loss. **Recommended: keep false.** Testing across all configurations showed TSL consistently cuts winners early, reducing overall profitability. |
| **trailingStrat** | 0 | Trailing strategy: 0=Fixed points, 1=ATR-based |
| **trailingStopPoints** | 800 | Distance in points for fixed trailing stop. |
| **tslTrigger** | 0 | Fibonacci trigger level at which TSL activates. |

---

### 4. Trade Timeframes

| Parameter | Default | Description |
|---|---|---|
| **CTOB** | M15 (15) | Signal timeframe — the timeframe where Order Blocks are detected. M15 is the validated optimum for XAUUSD. Do not change without retesting. |
| **HTOB** | H1 (16385) | Higher timeframe for trend direction. H1 confirmed best. |
| **ltf** | M5 (5) | Lower timeframe for MSS confirmation (used in AUTO entry mode). |
| **dptf** | H4 (16392) | Timeframe for PD arrays (Premium/Discount zones). |

---

### 5. Display Settings

| Parameter | Default | Description |
|---|---|---|
| **showOB** | false | Display all detected Order Blocks on chart, including those below the 3-star threshold. |
| **displayPP** | true | Display pivot points on chart. |
| **displayPremiumDiscount** | false | Display Premium/Discount zone levels. |
| **displayCPR** | false | Display CPR (Central Pivot Range) levels. |
| **EnableClock** | true | Display trading clock synced to GMT server time. |
| **displayICTLiquidity** | true | Display ICT liquidity levels. |
| **displayHTFTrend** | false | Display higher timeframe trend direction indicator. |
| **displayICTInducement** | false | Display ICT inducement zones. |
| **displayICTLiquidtySweep** | true | Display liquidity sweep detection markers. |
| **displayFVG** | true | Display Fair Value Gap zones on chart. |

---

### 6. Money Management

The lot size is calculated dynamically based on a percentage of your **free margin**, scaled by a risk ladder as your balance grows.

| Parameter | Default | Description |
|---|---|---|
| **enableMM** | true | Enable dynamic lot sizing. If false, uses `inpMinimallotsize` as fixed lot for every trade. |
| **inpMinimallotsize** | 0.01 | Minimum lot size. Never goes below this, even if MM calculates a smaller value. |
| **enableProtection** | true | Move stop loss to breakeven after price reaches the first TP trigger. |
| **isRangeTradingOK** | true | Allow trading when the H1 trend is RANGE (not trending). |
| **typeAccount** | Free Margin | Base account value used for risk calculation. Default uses free margin. |
| **FirstBalance** | 1000 | Risk threshold 1. When free margin is below this, use `riskByTrade` (maximum risk). |
| **SecondBalance** | 2000 | Risk threshold 2. Between First and Second balance, risk is linearly interpolated. Above Second balance, use `minRiskByTrade` (minimum risk). |
| **riskByTrade** | 0.20 (20%) | Maximum risk per trade as % of free margin, applied when balance < FirstBalance. |
| **minRiskByTrade** | 0.10 (10%) | Minimum risk per trade as % of free margin, applied when balance > SecondBalance. |
| **clsPositiveTradeOnClose** | false | Close all profitable trades 15 min before market close to avoid weekend/overnight swap. |
| **maximalDailyLoss** | 0.3 (30%) | Daily loss limit as % of balance. Once reached, EA stops trading until the next day and sends a notification. |
| **PartialMode** | true | Split the position in half at the first take profit level. Reduces risk while keeping a runner. |

---

### 7. News Filter

Pauses the EA around high-impact news events. **Only active in live trading** (not in Strategy Tester).

| Parameter | Default | Description |
|---|---|---|
| **EnableCheckNews** | true | Enable news filter. Requires internet access from your VPS/PC for MQL5 economic calendar. |
| **Npair** | USD | Currency pair to monitor for news (USD for XAUUSD). |
| **NewsImportanceLevel** | 3 | Minimum impact level to trigger a pause. 3 = High impact only. |
| **MinutesBeforeNews** | 30 | Stop trading this many minutes before a news event. |
| **MinutesAfterNews** | 30 | Resume trading this many minutes after a news event. |

---

### 8. ICT Kill Zone Filter

Restricts OB detection to specific high-probability trading windows. Order Blocks detected outside these hours are immediately discarded.

> These settings are automatically configured when using a Risk Profile preset (except Custom).

| Parameter | Default | Description |
|---|---|---|
| **inpKillZoneEnabled** | true | Enable Kill Zone time filter. Strongly recommended. |
| **inpKZ1Start** | 11 | Kill Zone 1 start hour (GMT). London late morning. |
| **inpKZ1End** | 14 | Kill Zone 1 end hour (GMT). Pre-NY open. |
| **inpKZ2Start** | 20 | Kill Zone 2 start hour (GMT). NY close session start. |
| **inpKZ2End** | 23 | Kill Zone 2 end hour (GMT). NY close session end. |

---

### 9. Market Structure Filters

Cascade of trend filters that reject Order Blocks trading against the prevailing trend direction.

| Parameter | Default | Description |
|---|---|---|
| **inpMacroTrendEnabled** | true | Skip all OBs when the **W1 (weekly)** trend is RANGE. Avoids trading during choppy macro conditions. |
| **inpRequireD1Trend** | true | Reject OBs that trade against the **D1 (daily)** trend. Validated on 2022–2025 OOS data — keeps default true. |
| **inpRequireH4Trend** | false | Reject OBs that trade against the **H4** trend. Tested and found to reduce profitability — leave false. |
| **inpRequireSwingStructure** | false | Require the OB to be at a significant H1 swing high (for sells) or swing low (for buys). Tested and rejected — leave false. |

The active filter cascade for the Conservative profile (recommended) is: **W1 macro → D1 trend → Daily bias → Kill Zone.**

---

### 10. Dynamic Lot Sizing

Scale trade size based on signal quality (top impulse confirmation).

| Parameter | Default | Description |
|---|---|---|
| **inpDynamicLot** | false | Enable dynamic lot multiplier based on signal quality. |
| **inpDynLotHighMult** | 1.25 | Lot multiplier when top impulse is confirmed (high-quality signal). Must be ≥ 1.0. |
| **inpDynLotLowMult** | 0.80 | Lot multiplier when top impulse is not confirmed (lower-quality signal). |

---

### 11. Watchlist Panel

Displays a real-time multi-symbol dashboard showing open positions and pending orders across all charts where the EA is running. Useful when trading multiple symbols simultaneously.

| Parameter | Default | Description |
|---|---|---|
| **inpShowWatchlist** | false | Show the watchlist panel. Only useful if running the EA on multiple charts. |
| **inpWatchlist** | EURUSD,GBPUSD,... | Comma-separated list of symbols to monitor. |

The panel shows: symbol name, trade direction (BUY/SEL/MIX), total lots, unrealised P&L, and pending order count. It updates every 30 seconds. Only enable if running multi-pair.

---

### 12. Trading Debug

| Parameter | Default | Description |
|---|---|---|
| **enableScreenshot** | true | Save a screenshot when a trade closes. |
| **ScreenshotWidth** | 1920 | Screenshot width in pixels. |
| **ScreenshotHeight** | 1080 | Screenshot height in pixels. |
| **FolderName** | Screenshots/ | Destination folder inside `MQL5/Files/`. |
| **enableSqlite** | false | Export trade events to a SQLite database for external analysis. |

---

### 13. Backtesting

| Parameter | Default | Description |
|---|---|---|
| **inpMaxTesterDD** | 40% | Maximum drawdown limit during backtesting. EA stops if this is exceeded (used with OnTester scoring). |
| **inpShowSymbolProfile** | false | Show the symbol profile panel (ATR, spread, lot analysis) in backtesting mode. |
| **inpProfileMaxAgeDays** | 30 | Number of days before the symbol profile is considered stale and needs re-evaluation. |

---

## Startup Diagnostics Panel

On startup (live trading only), the EA runs a series of checks and displays a warning panel in the upper-center of the chart if issues are found:

- **Min lot vs broker minimum** — warns if your `inpMinimallotsize` is below the broker's minimum
- **Insufficient margin** — warns if free margin cannot cover even the minimum lot size
- **Trading disabled** — warns if the broker has restricted trading on this symbol (DISABLED, CLOSE ONLY, LONG/SHORT ONLY)
- **Kill Zone hour conflict** — warns if KZ start >= end
- **SL conflict** — warns if MaxSL < MinSL
- **DynLot multiplier** — warns if HighMult < 1.0 (reduces size on best setups)
- **Balance ladder** — warns if FirstBalance > SecondBalance

Click the **[x]** button on the panel to dismiss it.

---

## Live Trading Checklist

Before going live on XAUUSD:

1. **Set inpMaxSpread** — use 30–50 points to avoid entries during spread spikes at news/rollover
2. **Verify GMT alignment** — the EA uses `TimeGMT()` for Kill Zone hours. Confirm your broker's server time matches GMT on the clock display
3. **Check news filter** — confirm `EnableCheckNews=true` works on your VPS (requires MQL5 calendar access)
4. **Adjust balance thresholds** — set `FirstBalance` and `SecondBalance` to match your actual account size
5. **Use PROFILE_CONSERVATIVE** — the validated default for XAUUSD
6. **Start at reduced risk** — consider `riskByTrade=0.05–0.10` for the first 3–6 months until you have 15+ live trades

---

## Backtesting Recommendations

- **Model**: Always use MODEL=4 (Every tick based on real ticks) for reliable results
- **Symbol**: XAUUSD M15 (validated configuration)
- **Period**: 2022–2026 for full OOS validation
- **Deposit**: $10,000 (matches documented baseline)
- **Spread**: Use broker's real spread or a conservative 20–30 points for gold

**Reference results (PROFILE_CONSERVATIVE, 2022–2025):**

| Metric | Value |
|---|---|
| Total trades | 14 |
| Win rate | 79% (11/14) |
| Profit Factor | 3.50 |
| Sharpe Ratio | 15.53 |
| Max Drawdown | 11.48% |
| Recovery Factor | 3.37 |
| Final Balance | $26,520 |
