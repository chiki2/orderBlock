#include <Trade\Trade.mqh>

// Input parameters
input int LookbackPeriod = 20;          // Lookback period for range detection
input double ATR_Threshold = 0.0005;    // ATR threshold for consolidation
input int ATR_Period = 14;              // ATR period
input double LotSize = 0.1;             // Lot size for trading
input double RiskRewardRatio = 2.0;     // Risk-reward ratio for TP
input int MaxBarsForRectangle = 50;     // Max bars for rectangle duration

// Global variables
CTrade trade;
double rangeHigh, rangeLow;
datetime rangeStartTime, rangeEndTime;
bool inConsolidation = false;
bool positionOpened = false;
string rectangleName = "ConsolidationRange";

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set symbol for CTrade
   trade.SetExpertMagicNumber(123456);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if a position is already open
   if(PositionSelect(_Symbol))
   {
      positionOpened = true;
      return;
   }
   else
   {
      positionOpened = false;
   }

   // Get current ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   int atrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
      return;

   // Get price data
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, _Period, 0, LookbackPeriod, high) <= 0 ||
      CopyLow(_Symbol, _Period, 0, LookbackPeriod, low) <= 0 ||
      CopyClose(_Symbol, _Period, 1, 1, close) <= 0)
      return;

   // Detect consolidation
   if(atr[0] < ATR_Threshold && !inConsolidation)
   {
      // Define range
      rangeHigh = high[ArrayMaximum(high, 0, LookbackPeriod)];
      rangeLow = low[ArrayMinimum(low, 0, LookbackPeriod)];
      rangeStartTime = TimeCurrent() - (LookbackPeriod * PeriodSeconds(_Period));
      rangeEndTime = TimeCurrent();

      // Draw rectangle
      DrawRangeRectangle();
      inConsolidation = true;
   }
   else if(atr[0] >= ATR_Threshold && inConsolidation)
   {
      // Remove rectangle if no longer in consolidation
      ObjectDelete(0, rectangleName);
      inConsolidation = false;
   }

   // Check for breakout
   if(inConsolidation && !positionOpened)
   {
      double currentPrice = close[0];
      double rangeSize = rangeHigh - rangeLow;
      double slDistance = rangeSize;
      double tpDistance = rangeSize * RiskRewardRatio;

      // Bullish breakout
      if(currentPrice > rangeHigh)
      {
         double sl = currentPrice - slDistance;
         double tp = currentPrice + tpDistance;
         trade.Buy(LotSize, _Symbol, 0, sl, tp, "Bullish Breakout");
         ObjectDelete(0, rectangleName);
         inConsolidation = false;
      }
      // Bearish breakout
      else if(currentPrice < rangeLow)
      {
         double sl = currentPrice + slDistance;
         double tp = currentPrice - tpDistance;
         trade.Sell(LotSize, _Symbol, 0, sl, tp, "Bearish Breakout");
         ObjectDelete(0, rectangleName);
         inConsolidation = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw consolidation range rectangle                                 |
//+------------------------------------------------------------------+
void DrawRangeRectangle()
{
   ObjectDelete(0, rectangleName);
   ObjectCreate(0, rectangleName, OBJ_RECTANGLE, 0, rangeStartTime, rangeHigh, rangeEndTime, rangeLow);
   ObjectSetInteger(0, rectangleName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, rectangleName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, rectangleName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, rectangleName, OBJPROP_FILL, false);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, rectangleName);
}