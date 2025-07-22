//+------------------------------------------------------------------+
//|                                                       inputs.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

enum trailingstopStrat
  {
   CLASSIC_TRAILING_STOP, // Classic Trailing Stop
   ATR_BASED_TRAILING_STOP// ATR Based Trailing Stop
  };

input group                "General settings"
input int uniqueMagicNumber= 1234555;
input int lookBackPeriod   = 100; // for history
input int minBdyLast       = 10; // body size of the first candle
input int minBodySize      = 10; // body size of the second candle
input int minImBalanced    = 10; // minimum imbalanced
input ENUM_TIMEFRAMES HTOB = PERIOD_M6;
input bool showOB          = false; // show all OrderBlock (even these with less than 3 stars)
input bool showDebug       = false; // Show debug messages
input bool  maxGain        = true; // Enable Max gain (TP and SL upgrade as long as the price action goes in the way of the order block)
input int   outdatedOB     = 8; // in hours, max time an order block is alive


input group             "Trading settings"
input bool                 enableOrderBlock        = true; // Enable Order Block trading
input bool                 forbidMondayFriday      = true; // no trade on friday and monday
input bool                 enableTrailingStop      = true; // enable trailing stop
input trailingstopStrat    trailingStrat           = CLASSIC_TRAILING_STOP; // trailing stop strategy
input double               trailingStopPoints      = 300; // enable trailing stop distance
input bool                 isCrypto                = false; // if symbol is crypto , allow 24/7 trading
input int                  ADX_Period              = 14; // ADX Period
input double               ADX_Threshold           = 25.0; // ADX Threshold
input int                  Fast_MA_Period          = 10;   // Fast MA Period
input int                  Slow_MA_Period          = 50;   // Slow MA Period
input int                  ATR_Period              = 14; // ATR period
input double               ATR_multiplier          = 2; // ATR multiplier
input bool                 clsPositiveTradeOnClose = true; //enable positive trade to close before market closure to avoid swap
input double               fiboEntry               = 0.5; // Set entry price based on fibonacci
input double               fibo1rstTP              = 1.27; // Set first TP based on fibonacci
input double               fiboProtectTrigger      = 0.8;
input double               fibo1rstTrigger         = 1.0;
input double               fibo2ndTP               = 1.618; // Set second TP based on fibonacci
input double               fibo2ndTrigger          = 1.4;
input double               fibo3rdTP               = 2.3812; // Set second TP based on fibonacci
input double               fibo3rdTrigger          = 2.0;
input bool                 enableDPICT             = true; // Enable Discount / Premium Zone
input ENUM_TIMEFRAMES      dptf                    = PERIOD_H4; // timeframe to set Discount / premium Zone

input group             "Liquidity Sweep prevention"
input int                  lookbackBars = 5;         // Swing detection sensitivity
input double               wickTolerance = 0.5;       // Tolerance for wick deviation in points
input int                  obDurationBars = 10;      // How many bars to scan after the OB

input group             "Money management settings"
input bool                 enableMM                = true; // Enable money management setting
input double               inpMinimallotsize       = 0.01; // minimal lot size
input double               FirstBalance            = 1000; // First balance (maximum risk by trade)
input double               SecondBalance           = 2000; // Second balance (use minimal risk by trade)
input double               riskByTrade             = 0.20; // Maximum risk by trade if balance is under 1rstBalance
input double               minRiskByTrade          = 0.05; // Minimum risk by trade if balance is over 2nd balance
input double               inpStopLossPoints       = 100;  // Stop loss points
input double               maximalDailyLoss        = 0.3;  // Maximal authorized daily loss ( will stop for the rest of the day )


input group             "Trading debug"
input bool enableScreenshot= true; // Enable Screenshot for TP & SL
input int ScreenshotWidth = 1920;  // Screenshot width
input int ScreenshotHeight = 1080; // Screenshot height
input string FolderName = "Screenshots/"; // Custom folder for saving screenshot


input group             "Panel settings"
input int                  InpX                    = 5;                // X-axis distance
input int                  InpY                    = 190;               // Y-axis distance
input string               InpFont                 = "Lucida Console";  // Font
input int                  InpFontSize             = 7;                // Font size
