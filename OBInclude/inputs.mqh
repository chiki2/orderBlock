//+------------------------------------------------------------------+
//|                                                       inputs.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#include "globals.mqh"


input group                "======== General settings ========"
input int uniqueMagicNumber= 1234555;
input int lookBackPeriod   = 50; // for history
input double maxWickRatio  = 1.5; // wick size OB candle
input int minBodySize      = 10; // body size OB candle
input int minImBalanced    = 10; // minimum imbalanced
input ENUM_TIMEFRAMES CTOB = PERIOD_M6; // current time frame
//input bool enableHTOB      = false; // Enable Order block trading confirmation with Higher timeframe
input ENUM_TIMEFRAMES HTOB = PERIOD_H2; // Higher time frame to check for OB
input bool showOB          = false; // show all OrderBlock (even these with less than 3 stars)
input bool  maxGain        = true; // Enable Max gain (TP and SL upgrade as long as the price action goes in the way of the order block)
input int   outdatedOB     = 80; // in candles, max number of candles an order block is alive
string correlatedSym = "USDX"; // Correlated symbol for Dollar Index


input group             "======== Trading settings ========"
input marketType           inpMarketMode           = OB_UK_NY; // Market selection
input bool                 forbidMondayFriday      = true; // no trade on friday and monday
input bool                 enableTrailingStop      = false; // enable trailing stop
input trailingstopStrat    trailingStrat           = ATR_BASED_TRAILING_STOP; // trailing stop strategy
input double               trailingStopPoints      = 150; // enable trailing stop distance
input trailingTrigger      tslTrigger              = TLS_TRIGGER_FIB238; // Trailing stop triggering level
input int                  ADX_Period              = 9; // ADX Period
input double               ADX_Threshold           = 25.0; // ADX Threshold
input double               ADX_Max                 = 60.0; // ADX Threshold
int                  Fast_MA_Period          = 15;   // Fast MA Period
int                  Slow_MA_Period          = 45;   // Slow MA Period
input int                  ATR_Period              = 20; // ATR period
input double               ATR_multiplier          = 3.5; // ATR multiplier
input MitigatedDL          MitigatedMode           = OB_MITIGATED_MIDLINE; // OB mitigation mode : OB High / midline / OB low
input tradeType            typeOfTrade             = BOTH; // Type of trade (Buy / Sell / Both);
input bool                 clsPositiveTradeOnClose = true; //enable positive trade to close before market closure to avoid swap
input double               fiboEntry               = 0.5; // Set entry price based on fibonacci
input double               fibo1rstTP              = 1.27; // Set first TP based on fibonacci
input double               fiboProtectTrigger      = 0.8;
input double               fibo1rstTrigger         = 1.0;
input double               fibo2ndTP               = 1.618; // Set second TP based on fibonacci
input double               fibo2ndTrigger          = 1.4;
input double               fibo3rdTP               = 2.3812; // Set second TP based on fibonacci
input double               fibo3rdTrigger          = 2.0;
input double               fiboExtended            = 8.0; // Fibonnacci Over extended level
input bool                 enableDPICT             = true; // Enable Discount / Premium Zone
input ENUM_TIMEFRAMES      dptf                    = PERIOD_H4; // timeframe to set Discount / premium Zone
input group             "======== Display settings ========"
input bool                 displayPP               = true; // Display Pivot Point
input bool                 displayCPR              = true; // Display CPR 
input bool                 EnableClock             = false;// Display clock trade server
input group             "======== Liquidity Sweep prevention ========"
input int                  lookbackBars = 10;         // Swing detection sensitivity
input double               wickTolerance = 2;      // Tolerance for wick deviation in points
input int                  obDurationBars = 5;      // How many bars to scan after the OB

input group             "======== Money management settings ========"
input bool                 enableMM                = true; // Enable money management setting
input double               inpMinimallotsize       = 0.01; // minimal lot size
input bool                 enableProtection        = false; // Protection : Breakeven + 30 points
input double               FirstBalance            = 1000; // First balance (maximum risk by trade)
input double               SecondBalance           = 2000; // Second balance (minimal risk by trade)
input double               riskByTrade             = 0.20; // Maximum risk < 1rstBalance
input double               minRiskByTrade          = 0.05; // Minimum risk > 2nd balance
input double               inpStopLossPoints       = 100;  // Stop loss points
input double               maximalDailyLoss        = 0.3;  // Maximal authorized daily loss ( will stop for the rest of the day )
//input double               obMeterScore            = 0.5; // Ob meter min. score to trade

input group             "======== News filter settings ========"
input bool     EnableCheckNews     = true;      // Enable News filtering
input string   Npair               = "USD";     // Currency to filter news on
input int      NewsImportanceLevel = 3;        // High impact level (1=Low, 2=Medium, 3=High)
input int      MinutesBeforeNews = 30;      // Minutes before news to stop trading
input int      MinutesAfterNews = 30;       // Minutes after news to resume trading

input group             "======== Trading debug ========"
input bool enableScreenshot= true; // Enable Screenshot for TP & SL
input int ScreenshotWidth = 1920;  // Screenshot width
input int ScreenshotHeight = 1080; // Screenshot height
input string FolderName = "Screenshots/"; // Custom folder for saving screenshot

//input group             "Panel settings"
int                  InpX                    = 5;                // X-axis distance
int                  InpY                    = 260;               // Y-axis distance
string               InpFont                 = "Lucida Console";  // Font
int                  InpFontSize             = 7;                // Font size


// KDE Input parameters

enum ENUM_KERNEL_TYPE
  {
   KERNEL_GAUSSIAN,  // Gaussian Kernel
   KERNEL_UNIFORM,   // Uniform Kernel
   KERNEL_SIGMOID    // Sigmoid Kernel
  };

/*
input group             "======== Trading debug ========"
input double lot_size = 0.1;            // Lot Size
input int rsi_period = 14;              // RSI Period
input int pivot_length = 21;            // Pivot Length (bars before/after)
input double kde_bandwidth = 0.1;       // KDE Bandwidth
input int kde_steps = 200;              // KDE Number of Steps
input double kde_threshold = 0.7;       // KDE Activation Threshold
input ENUM_KERNEL_TYPE kernel_type = KERNEL_GAUSSIAN; // Kernel Type
input double stop_loss_pips = 50.0;     // Stop Loss (pips)
input double take_profit_pips = 100.0;  // Take Profit (pips)
input int max_positions = 1;            // Max Open Positions
*/

//+------------------------------------------------------------------+
