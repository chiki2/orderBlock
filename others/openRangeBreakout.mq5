//+------------------------------------------------------------------+
//| ORB_EURUSD.mq5                                                   |
//| Open Range Breakout Strategy for EURUSD with Visual Range Objects |
//| Executes on new bar, trades breakouts, draws range high/low lines |
//+------------------------------------------------------------------+
#property copyright "xAI Generated"
#property link      "https://x.ai"
#property version   "1.03"

#include <Trade/Trade.mqh>

//--- Input parameters
input double RiskPercent = 1.0;       // Risk per trade (% of equity)
input int RangeMinutes = 30;          // Open range duration (minutes)
input string RangeStartTime = "08:00"; // Range start time (HH:MM)
input string DayEndTime = "22:00";    // End of trading day (HH:MM)
input double TpMultiplier = 2.0;      // Take profit multiplier (x Stop Loss)
input int MagicNumber = 123456;       // Unique trade identifier
input bool DrawRangeObjects = true;   // Draw visual range objects
input color HighLineColor = clrLime;  // Color for range high line
input color LowLineColor = clrRed;    // Color for range low line


//--- Global variables
datetime lastBarTime = 0;
datetime rangeStart, rangeEnd, dayEnd;
double rangeHigh = 0, rangeLow = 0;
bool rangeSet = false;
int positionTicket = 0;
string objectPrefix = "ob-break_";
CTrade obj_Trade;

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
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
  {
// Validate inputs
   if(RiskPercent <= 0 || RangeMinutes <= 0 || TpMultiplier <= 0)
     {
      Print("Invalid input parameters");
      return(INIT_PARAMETERS_INCORRECT);
     }

// Convert times to datetime
   rangeStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " " + RangeStartTime);
   rangeEnd = rangeStart + RangeMinutes * 60;
   dayEnd = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " " + DayEndTime);

// Clean up any existing objects
   if(DrawRangeObjects)
      DeleteOldObjects();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
// Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime != lastBarTime)
     {
      lastBarTime = currentBarTime;
      ProcessNewBar();
      ClosePosition();

     }
  }

//+------------------------------------------------------------------+
//| Process logic on new bar                                          |
//+------------------------------------------------------------------+
void ProcessNewBar()
  {
   datetime currentTime = TimeCurrent();

// Adjust range times for the current day
   string today = TimeToString(currentTime, TIME_DATE);
   rangeStart = StringToTime(today + " " + RangeStartTime);
   rangeEnd = rangeStart + RangeMinutes * 60;
   dayEnd = StringToTime(today + " " + DayEndTime);

// Step 1: Set the open range
   if(currentTime >= rangeStart && currentTime <= rangeEnd && !rangeSet)
     {
      UpdateRange();
     }
   else
      if(currentTime > rangeEnd && rangeSet)
        {
         // Step 2: Check for breakouts if range is set and no position is open
         if(positionTicket == 0)
           {
            CheckBreakouts();
           }
        }

// Step 3: Close position at end of day
   if(currentTime >= dayEnd && positionTicket != 0)
     {
      ClosePosition();
     }

// Reset range and objects for the next day
   if(currentTime > dayEnd)
     {
      if(DrawRangeObjects)
         DeleteOldObjects();
      rangeSet = false;
      rangeHigh = 0;
      rangeLow = 0;
     }
  }

//+------------------------------------------------------------------+
//| Update the open range high and low, draw visual objects           |
//+------------------------------------------------------------------+
void UpdateRange()
  {
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
      if(DrawRangeObjects)
        {
         string objName = objectPrefix + TimeToString(rangeStart, TIME_DATE|TIME_MINUTES);
         DrawRangeLines(objName);
        }
     }
  }

//+------------------------------------------------------------------+
//| Draw horizontal lines for range high and low                     |
//+------------------------------------------------------------------+
void DrawRangeLines(string baseName)
  {
// High line
   string highName = baseName + "_High";
   if(!ObjectCreate(0, highName, OBJ_HLINE, 0, 0, rangeHigh))
     {
      Print("Failed to create high line: ", GetLastError());
      return;
     }
   ObjectSetInteger(0, highName, OBJPROP_COLOR, HighLineColor);
   ObjectSetInteger(0, highName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, highName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, highName, OBJPROP_BACK, false);

// Low line
   string lowName = baseName + "_Low";
   if(!ObjectCreate(0, lowName, OBJ_HLINE, 0, 0, rangeLow))
     {
      Print("Failed to create low line: ", GetLastError());
      return;
     }
   ObjectSetInteger(0, lowName, OBJPROP_COLOR, LowLineColor);
   ObjectSetInteger(0, lowName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, lowName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lowName, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Delete old range objects                                         |
//+------------------------------------------------------------------+
void DeleteOldObjects()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string objName = ObjectName(0, i, -1, -1);
      if(StringFind(objName, objectPrefix) == 0)
        {
         ObjectDelete(0, objName);
        }
     }
  }

//+------------------------------------------------------------------+
//| Check for breakout and place trades                               |
//+------------------------------------------------------------------+
void CheckBreakouts()
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

// Calculate lot size based on risk
   double rangeSize = rangeHigh - rangeLow;
   double stopLossPips = rangeSize / _Point;
   double lotSize = CalculateLotSize(stopLossPips);

// Buy breakout
   if(currentPrice > rangeHigh)
     {
      double sl = rangeLow;
      double tp = currentPrice + (currentPrice - sl) * TpMultiplier;
      if(PlaceTrade(ORDER_TYPE_BUY, lotSize, sl, tp))
        {
         Print("Buy trade placed: Price=", currentPrice, ", SL=", sl, ", TP=", tp);
        }
     }
// Sell breakout
   else
      if(currentPrice < rangeLow)
        {
         double sl = rangeHigh;
         double tp = currentPrice - (sl - currentPrice) * TpMultiplier;
         if(PlaceTrade(ORDER_TYPE_SELL, lotSize, sl, tp))
           {
            Print("Sell trade placed: Price=", currentPrice, ", SL=", sl, ", TP=", tp);
           }
        }
  }

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPips)
  {
   double accountEquity = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double riskAmount = accountEquity * RiskPercent / 100.0;
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
//| Place a trade                                                     |
//+------------------------------------------------------------------+
bool PlaceTrade(ENUM_ORDER_TYPE orderType, double lotSize, double sl, double tp)
  {


   if(orderType == ORDER_TYPE_BUY)
     {
      obj_Trade.BuyLimit(lotSize,SymbolInfoDouble(_Symbol,  SYMBOL_ASK),_Symbol,sl, tp,ORDER_TIME_DAY);
     }
   else
     {

      //obj_Trade.SellLimit(lotSize,SymbolInfoDouble(_Symbol,  SYMBOL_ASK),_Symbol,sl, tp,ORDER_TIME_DAY);
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Close open position                                               |
//+------------------------------------------------------------------+
void ClosePosition()
  {
   int CloseMinutesBeforeMarketClose = 15 ; // In minutes
   datetime nowDT = TimeCurrent();
   MqlDateTime open, close, now;
   datetime openDT, closeDT;
   bool sessionTrade = SymbolInfoSessionTrade(_Symbol,MONDAY, 0, openDT, closeDT);
   TimeToStruct(openDT, open);
   TimeToStruct(closeDT, close);
   TimeToStruct(nowDT, now);

// Close only if within CloseMinutesBeforeMarketClose minutes before market close
   if(close.min - now.min <= CloseMinutesBeforeMarketClose &&
      now.hour == close.hour) // same hour
     {


      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) != 0 )
           {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if ( profit > 0 ){
               obj_Trade.PositionClose(ticket);
            }
            
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(positionTicket != 0)
     {
      ClosePosition();
     }
   if(DrawRangeObjects)
      DeleteOldObjects();
  }
//+------------------------------------------------------------------+
