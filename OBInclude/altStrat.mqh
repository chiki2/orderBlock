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

int RangeBarShift(string symbol, ENUM_TIMEFRAMES timeframe, datetime sourceTime, bool exact = false)
  {
   if(sourceTime <= 0)
      return -1;

   datetime barTimes[];
   ArraySetAsSeries(barTimes, true);
   int total = Bars(symbol, timeframe);
   if(total <= 0)
      return -1;

   int copied = CopyTime(symbol, timeframe, 0, total, barTimes);
   if(copied <= 0)
      return -1;

   for(int i = 0; i < copied; i++)
     {
      if(exact == true)
        {
         if(barTimes[i] == sourceTime)
            return i;
        }
      else
        {
         if(sourceTime >= barTimes[i])
            return i;
        }
     }

   return -1;
  }

//+------------------------------------------------------------------+
//| Update the open range high and low, draw visual objects           |
//+------------------------------------------------------------------+
void UpdateRange(datetime currentPrice)
  {
   ObjectsDeleteAll(0,objectPrefix);

// Validate time range
   if(rangeStart >= rangeEnd || rangeStart == 0 || rangeEnd == 0)
     {
      Print("Invalid range times: Start=", rangeStart, ", End=", rangeEnd);
      return;
     }

// Get bar indices for the range period
   int startShift = RangeBarShift(_Symbol, _Period, rangeStart, true);
   int endShift = RangeBarShift(_Symbol, _Period, rangeEnd, true);

// Check if shifts are valid
   if(startShift < 0 || endShift < 0 || startShift <= endShift)
     {
      Print("Invalid bar shifts: StartShift=", startShift, ", EndShift=", endShift);
      return;
     }

// Calculate number of bars in the range
   int bars = startShift - endShift + 1;
   if(bars <= 0)
     {
      Print("No bars found in range: ", TimeToString(rangeStart), " to ", TimeToString(rangeEnd));
      return;
     }

// Calculate range high and low
   rangeHigh = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, bars, endShift));
   rangeLow = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, bars, endShift));

   if(rangeHigh > rangeLow)
     {
      rangeSet = true;
      Print("Range set: High=", rangeHigh, ", Low=", rangeLow, ", Time=", TimeToString(rangeStart), ", Range end=", TimeToString(rangeEnd));

      // Draw visual objects if enabled
      string objName = objectPrefix + TimeToString(rangeStart, TIME_DATE|TIME_MINUTES);
      maxPriceRange = (rangeHigh + (rangeHigh - rangeLow));
      maxPriceRangeLow = (rangeLow - (rangeHigh - rangeLow));
      DrawRangeLines(objName);
     }
  }


//+------------------------------------------------------------------+
//| Range breakout Process logic on new bar                          |
//+------------------------------------------------------------------+
void RangeBreakout()
  {
   if(enableRangeBK == false)
      return;



   MqlDateTime mdt;
   datetime currentTime = TimeGMT(mdt);
// Adjust range times for the current day
   string today = TimeToString(currentTime, TIME_DATE);
   rangeStart = StringToTime(today + " " + ((Inp_Hour < 10) ? "0" + IntegerToString(Inp_Hour) : IntegerToString(Inp_Hour)) + ":" + ((Inp_Minute < 10) ? "0" + IntegerToString(Inp_Minute) : IntegerToString(Inp_Minute)));
   rangeEnd = rangeStart + RangeMinutes * 60;
   dayEnd = StringToTime(today + " " + DayEndTime);

// Step 1: Set the open range
   if(currentTime >= rangeStart  && rangeSet == false)
     {
      UpdateRange(currentTime);
     }
   else
     {

      if(currentTime > rangeEnd && rangeSet == true)
        {
         // Step 2: Check for breakouts if range is set and no position is open
         CheckBreakouts();
        }
     }

   ClosePositiveTrades();

// Reset range and objects for the next day
   if(currentTime > dayEnd)
     {
      rangeSet = false;
      rangeHigh = 0;
      rangeLow = 0;
     }
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Range breakout Check for breakout and place trades               |
//+------------------------------------------------------------------+
int CheckBreakouts()
  {
     rangeStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " " + IntegerToString(Inp_Hour) + ":" + IntegerToString(Inp_Minute));
   rangeEnd = rangeStart + RangeMinutes * 60;
   dayEnd = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " " + DayEndTime);
   RangeBreakout();

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

      StopLevels adjusted = AdjustStopLevels(Ask(), sl, tp, true);
      tp = adjusted.takeProfit;
      sl = adjusted.stopLoss;

      if(RSI < 65 && RSI > 20)
        {
         obj_Trade.BuyLimit(checkVolume(rangeLotSize),Ask(),_Symbol,sl, tp,ORDER_TIME_DAY,0,"Range Trade");
         sendNotif("Range 0.01 Buy @" + DoubleToString(Ask()) + " on " + _Symbol);
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

      StopLevels adjusted = AdjustStopLevels(Bid(), sl, tp, false);
      tp = adjusted.takeProfit;
      sl = adjusted.stopLoss;


      if(RSI < 65 && RSI > 20)
        {
         obj_Trade.SellLimit(0.01,Bid(),_Symbol,sl, tp,ORDER_TIME_DAY,0,"Range Trade");
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
//|                                                                  |
//+------------------------------------------------------------------+
void detectConsolidationRange()
  {
   double ATR_Threshold = 1.2;
   if(enableConsolidationBK == false)
     {
      return ;
     }
// Get current ATR
   ArraySetAsSeries(atr, true);
   int atrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
     {
      Print("No valid data for ATR");
      return;
     }

// Get price data
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, _Period, 0, LookbackPeriod, high) <= 0 ||
      CopyLow(_Symbol, _Period, 0, LookbackPeriod, low) <= 0 ||
      CopyClose(_Symbol, _Period, 1, 1, close) <= 0)
     {
      return;
     }

// Detect consolidation
   if(atr[0] < ATR_Threshold &&
      inConsolidation == false &&
      atr[0] > 0)
     {
      Print("Consolidation detected");
      // Define range
      CrangeHigh = high[ArrayMaximum(high, 0, LookbackPeriod)];
      CrangeLow = low[ArrayMinimum(low, 0, LookbackPeriod)];
      CrangeStartTime = TimeCurrent() - (LookbackPeriod * PeriodSeconds(_Period));
      CrangeEndTime = TimeCurrent();

      // Draw rectangle
      DrawRangeRectangle();
      inConsolidation = true;
     }
   else
      if(atr[0] >= ATR_Threshold && inConsolidation == true)
        {
         Print("Consolidation invalid");
         // Remove rectangle if no longer in consolidation
         ObjectDelete(0, rectangleName);
         inConsolidation = false;
        }

// Check for breakout
   if(inConsolidation == true && positionOpened == false)
     {
      double currentPrice = close[0];
      double CrangeSize = CrangeHigh - CrangeLow;
      double CrangeSizePoint = CrangeSize / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double protectSL  = inpStopLossPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double slDistance = /*(CrangeSizePoint > inpStopLossPoints) ? protectSL  : */CrangeSize ;
      double tpDistance = CrangeSize * RiskRewardRatio;




      // Bullish breakout
      if(currentPrice > CrangeHigh &&
         currentPrice > ema[1]
         /*&&
         RSI < 60 && RSI > 20*/)
        {
         double sl = currentPrice - slDistance;
         double tp = currentPrice + tpDistance;

         StopLevels adjusted = AdjustStopLevels(currentPrice, sl, tp, true);
         tp = adjusted.takeProfit;
         sl = adjusted.stopLoss;

         obj_Trade.Buy(checkVolume(ConsoLotSize), _Symbol, 0, sl, tp, "Range Consolidation");
         sendNotif("Consolidation Range 0.01 Buy @" + DoubleToString(currentPrice) + " on " + _Symbol);
         ObjectDelete(0, rectangleName);
         inConsolidation = false;
        }
      // Bearish breakout
      else
         if(currentPrice < CrangeLow &&
            currentPrice < ema[1]
            /*&&
               RSI > 60 && RSI > 40*/)
           {
            double sl = currentPrice + slDistance;
            double tp = currentPrice - tpDistance;

            StopLevels adjusted = AdjustStopLevels(currentPrice, sl, tp, false);
            tp = adjusted.takeProfit;
            sl = adjusted.stopLoss;

            obj_Trade.Sell(checkVolume(ConsoLotSize), _Symbol, 0, sl, tp, "Range Consolidation");
            sendNotif("Consolidation Range 0.01 Sell @" + DoubleToString(currentPrice) + " on " + _Symbol);
            ObjectDelete(0, rectangleName);
            inConsolidation = false;
           }
     }
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Range breakout Draw horizontal lines for range high and low      |
//+------------------------------------------------------------------+
void DrawRangeLines(string baseName)
  {

// start vertical line rangeStart
   string startName = baseName + "_start";
   if(!ObjectCreate(0, startName, OBJ_VLINE, 0, rangeStart, 0))
     {
      Print("Failed to create high line: ", GetLastError());
      return;
     }
   ObjectSetInteger(0, startName, OBJPROP_COLOR, clrBlueViolet);
   ObjectSetInteger(0, startName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, startName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, startName, OBJPROP_BACK, false);
// end vertical line  rangeEnd
   string endName = baseName + "_start";
   if(!ObjectCreate(0, endName, OBJ_VLINE, 0, rangeEnd, 0))
     {
      Print("Failed to create high line: ", GetLastError());
      return;
     }
   ObjectSetInteger(0, endName, OBJPROP_COLOR, clrBlueViolet);
   ObjectSetInteger(0, endName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, endName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, endName, OBJPROP_BACK, false);

// High line
   string highName = baseName + "_High";
   if(!ObjectCreate(0, highName, OBJ_HLINE, 0, 0, rangeHigh))
     {
      Print("Failed to create high line: ", GetLastError());
      return;
     }
   ObjectSetInteger(0, highName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, highName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, highName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, highName, OBJPROP_BACK, false);

// High Max line
   if(rm == RANGE_SIZE_ZONE)
     {
      string MaxhighName = baseName + "_High_Max";
      if(!ObjectCreate(0, MaxhighName, OBJ_HLINE, 0, 0, maxPriceRange))
        {
         Print("Failed to create high line: ", GetLastError());
         return;
        }
      ObjectSetInteger(0, MaxhighName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, MaxhighName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, MaxhighName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, MaxhighName, OBJPROP_BACK, false);
     }
// Low line
   string lowName = baseName + "_Low";
   if(!ObjectCreate(0, lowName, OBJ_HLINE, 0, 0, rangeLow))
     {
      Print("Failed to create low line: ", GetLastError());
      return;
     }
   ObjectSetInteger(0, lowName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, lowName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, lowName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lowName, OBJPROP_BACK, false);

// low Max line
   if(rm == RANGE_SIZE_ZONE)
     {
      string MaxLowName = baseName + "_Low_Max";
      if(!ObjectCreate(0, MaxLowName, OBJ_HLINE, 0, 0, maxPriceRangeLow))
        {
         Print("Failed to create high line: ", GetLastError());
         return;
        }
      ObjectSetInteger(0, MaxLowName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, MaxLowName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, MaxLowName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, MaxLowName, OBJPROP_BACK, false);
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw consolidation range rectangle                                 |
//+------------------------------------------------------------------+
void DrawRangeRectangle()
  {
   ObjectDelete(0, rectangleName);
   ObjectCreate(0, rectangleName, OBJ_RECTANGLE, 0, CrangeStartTime, CrangeHigh, CrangeEndTime, CrangeLow);
   ObjectSetInteger(0, rectangleName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, rectangleName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, rectangleName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, rectangleName, OBJPROP_FILL, false);
  }

//+------------------------------------------------------------------+
