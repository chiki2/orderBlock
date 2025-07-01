//+------------------------------------------------------------------+
//|                                                     altStrat.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
enum rangeMode
  {
   RANGE_SIZE_ZONE, //Range size above Range high as limit
   RANGE_STOPLOSS  //Each trade keep range size as stoploss
  };

enum rangeOrder
  {
   BUY_ONLY, // Authorize buy order only
   SELL_ONLY,  // Authorize sell order only
   BUY_AND_SELL // Authorize both buy and sell order
  };

enum strat
  {
   STRAT_ORDER_BLOCK, // Order Block
   STRAT_OPEN_RANGE, // Open range breakout
   STRAT_RANGEBREAKOUT // Range Breakout
  };

input group             "Open Range Breakout"
input bool enableRangeBK = false; // enable range breakout
input rangeOrder ro      = BUY_ONLY; // buy only
input int RangeMinutes = 30;          // Open range duration (minutes)
input int Inp_Hour = 12; // Range start time hour(0-23)
input int Inp_Minute = 0; // Range start time hour(0-59)
input string DayEndTime = "22:00";    // End of trading day (HH:MM)
input double   MaxOrder = 0.20; // Percent of free margin to use for range order
input double TpMultiplier = 0.5;      // Take profit multiplier (x Stop Loss)
input double minRangeSize = 30.0; // Minimal Range size to take trade
input double maxRangeSize = 100.0; // Maximum Range size to take trade
input double rangeTS =  80.0; // trailing stop point for range order
input double rangeLotSize = 0.01; // Range lot size
input rangeMode rm = RANGE_SIZE_ZONE;


input group             "Consolidation Breakout"
input bool enableConsolidationBK = false; // enable range breakout
input int LookbackPeriod = 80;          // Lookback period for range detection
input double ConsoLotSize = 0.01;             // Lot size for trading
input double RiskRewardRatio = 2.0;     // Risk-reward ratio for TP
input int MaxBarsForRectangle = 50;     // Max bars for rectangle duration

//--- Global variables for range breakout
datetime rangeStart, rangeEnd, dayEnd;
double rangeHigh = 0, rangeLow = 0;
bool rangeSet = false;
int positionTicket = 0;
string objectPrefix = "ob-range";
int maxorderAmount = 1;
double currentPriceDistPT = 0.0;
double maxPriceRange = 0.0;
double maxPriceRangeLow= 0.0;
double CrangeHigh, CrangeLow;
datetime CrangeStartTime, CrangeEndTime;
bool inConsolidation = false;
bool positionOpened = false;
string rectangleName = "ConsolidationRange";

//+------------------------------------------------------------------+
//| Range breakout Check for breakout and place trades               |
//+------------------------------------------------------------------+
int CheckBreakouts()
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

// Calculate lot size based on risk
   double rangeSize = rangeHigh - rangeLow;
   double stopLossPips = rangeSize / _Point;
   double rangeSizePoint = rangeSize / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   maxPriceRange = rangeHigh + rangeSize;
   maxPriceRangeLow = rangeLow - rangeSize;

//double lotSize = CalculateLotSize(stopLossPips);
   maxorderAmount = (int)MathRound((AccountInfoDouble(ACCOUNT_MARGIN_FREE) * MaxOrder) / maxRangeSize); // max range size stoploss

   if(showDebug == true)
     {
      Print("EMA 1 hour " + DoubleToString(ema[1]));
     }

// Buy breakout
   if(currentPrice > rangeHigh &&
      rangeSizePoint < maxRangeSize &&
      rangeSizePoint > minRangeSize &&
      currentPrice > ema[1] &&
      (ro == BUY_ONLY || ro == BUY_AND_SELL)
     )
     {
      if(rm == RANGE_SIZE_ZONE && currentPrice > maxPriceRange)
        {
         if(showDebug == true)
           {
            Print("current price is over Max price range ");
           }
         return maxorderAmount;
        }


      double sl = (rm == RANGE_SIZE_ZONE) ?  rangeLow : currentPrice - rangeSize;
      double tp = currentPrice + (currentPrice - sl) * TpMultiplier;

      StopLevels adjusted = AdjustStopLevels(SymbolInfoDouble(_Symbol,  SYMBOL_ASK), sl, tp, true);
      tp = adjusted.takeProfit;
      sl = adjusted.stopLoss;

      if(RSI < 65 && RSI > 20)
        {
         obj_Trade.BuyLimit(checkVolume(rangeLotSize),SymbolInfoDouble(_Symbol,  SYMBOL_ASK),_Symbol,sl, tp,ORDER_TIME_DAY,0,"Range Trade");
         sendNotif("Range 0.01 Buy @" + DoubleToString(SymbolInfoDouble(_Symbol,  SYMBOL_ASK)) + " on " + _Symbol);
         if(showDebug == true)
            Print("Buy range trade placed: Price=", currentPrice, ", SL=", sl, ", TP=", tp);
        }

      else
        {
         if(showDebug == true)
            Print("Range Size too large ", DoubleToString(rangeSize / Point(),2));
        }
     }

// Sell breakout
   if(currentPrice < rangeLow &&
      rangeSizePoint < maxRangeSize &&
      rangeSizePoint > minRangeSize &&
      currentPrice < ema[1] &&
      (ro == SELL_ONLY || ro == BUY_AND_SELL))
     {

      if(rm == RANGE_SIZE_ZONE && currentPrice < maxPriceRangeLow)
        {
         if(showDebug == true)
           {
            Print("current price is over Max price range ");
           }
         return maxorderAmount;
        }

      double sl = (rm == RANGE_SIZE_ZONE) ? rangeLow : currentPrice - rangeSize;
      double tp = currentPrice + (currentPrice - sl) * TpMultiplier;

      StopLevels adjusted = AdjustStopLevels(SymbolInfoDouble(_Symbol,  SYMBOL_BID), sl, tp, false);
      tp = adjusted.takeProfit;
      sl = adjusted.stopLoss;


      if(RSI < 65 && RSI > 20)
        {
         obj_Trade.SellLimit(0.01,SymbolInfoDouble(_Symbol,  SYMBOL_BID),_Symbol,sl, tp,ORDER_TIME_DAY,0,"Range Trade");
         Print("Sell range trade placed: Price=", currentPrice, ", SL=", sl, ", TP=", tp);

        }
     }
   return (maxorderAmount != 0) ? maxorderAmount : 1;
  }

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Calculate lot size based on risk for range                       |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPips)
  {
   double accountEquity = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double riskAmount = accountEquity * 1 / 100.0;  // 1 risk percent
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotSize = riskAmount / (stopLossPips * tickValue / tickSize);

// Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   return lotSize;
  }
//+------------------------------------------------------------------+

