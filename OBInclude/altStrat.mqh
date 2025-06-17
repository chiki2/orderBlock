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
input double ATR_Threshold = 1.5;    // ATR threshold for consolidation
input int ATR_Period = 14;              // ATR period
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
double atr[];

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

      if(filterPositionByStrat(STRAT_OPEN_RANGE) < MathMax(maxorderAmount, 1) &&
         maxorderAmount < 30 /*&&
         RSI < 65 && RSI > 20*/)
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


      if(filterPositionByStrat(STRAT_OPEN_RANGE) < MathMax(maxorderAmount, 1) &&
         maxorderAmount < 30 /*&&
         RSI < 65 && RSI > 20*/)
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


//+------------------------------------------------------------------+
//|                           Lightbuzz call                         |
//+------------------------------------------------------------------+
void LightBuzzOrder(int i = 0)
  {
   if(enableLightBuzz == false)
     {return;}

   if(timeToTrade() == false)
     {
      return;
     }


   int barIndex            = iBarShift(_Symbol, HTOB, obBuffer[i].startTime, true);
   double bidPrice         = SymbolInfoDouble(_Symbol, SYMBOL_BID); // bear
   double askPrice         = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // bull

   if(
      obBuffer[i].isBear == false &&
      obBuffer[i].lightBuzzTicket == 0 &&
      obBuffer[i].fib23812 < bidPrice &&
      obBuffer[i].isLightbuzz == false &&
      obBuffer[i].OBcolor != clrPurple &&

      barIndex <= LightBuzzCandlesDetect)
     {
      Print("Lighbuzzzzz Sell ! ");
      obj_Trade.Buy(lotsizeCalculation(),_Symbol, bidPrice, bidPrice - 30 * Point(), 0,"lightbuzz trade");
      obBuffer[i].isLightbuzz = true;
      obBuffer[i].lightBuzzTicket = obj_Trade.ResultOrder();
      obBuffer[i].dolightbuzzTrailing = true;

     }
   if(
      obBuffer[i].isBear == true &&
      obBuffer[i].lightBuzzTicket == 0 &&
      obBuffer[i].fib23812 > askPrice &&
      obBuffer[i].isLightbuzz == false &&
      obBuffer[i].OBcolor != clrPurple &&
      barIndex <= LightBuzzCandlesDetect)
     {
      Print("Lighbuzzzzz buy ! ");
      obj_Trade.Sell(lotsizeCalculation(),_Symbol, askPrice, askPrice + 30 * Point(), 0,"lightbuzz trade");
      obBuffer[i].isLightbuzz = true;
      obBuffer[i].lightBuzzTicket = obj_Trade.ResultOrder();
      obBuffer[i].dolightbuzzTrailing = true;
     }
  }



//+------------------------------------------------------------------+
//|  Do revenge trade                                                |
//+------------------------------------------------------------------+
void doRevengeTrade(int i)
  {
   if(enableRevengeTrailingStop == false)
      return;

   if(timeToTrade() == false)
     {
      return;
     }


   double bidPrice         = SymbolInfoDouble(_Symbol, SYMBOL_BID); // bear
   double askPrice         = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // bull
   if(
      obBuffer[i].isBear == false &&
      obBuffer[i].OBcolor != clrPurple &&
      obBuffer[i].revengeTicket == 0 &&
      obBuffer[i].sweepRevenge == true &&
      obBuffer[i].startTime > TimeCurrent() - outdatedOB * 3600)
     {
      Print("Revenge sell ! ");
      obj_Trade.Sell(lotsizeCalculation(),_Symbol, askPrice, askPrice + 300 * Point(), 0,"revenge trade");
      obBuffer[i].isrevenge = true;
      obBuffer[i].revengeTicket = obj_Trade.ResultOrder();
      obBuffer[i].DoRevengeTrailing = true;

     }
   if(obBuffer[i].isBear == true &&
      obBuffer[i].OBcolor != clrPurple &&
      obBuffer[i].revengeTicket == 0 &&
      obBuffer[i].sweepRevenge == true &&
      obBuffer[i].startTime > TimeCurrent() - outdatedOB * 3600)
     {
      Print("Revenge buy ! ");
      obj_Trade.Buy(lotsizeCalculation(),_Symbol, bidPrice, bidPrice - 300 * Point(), 0,"revenge trade");
      obBuffer[i].isrevenge = true;
      obBuffer[i].revengeTicket = obj_Trade.ResultOrder();
      obBuffer[i].DoRevengeTrailing = true;
     }
  }