//+------------------------------------------------------------------+
//|                                               MasterPattern2.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
//--- Input Parameters
input group "Timeframe Settings"
input ENUM_TIMEFRAMES HTF_Period = PERIOD_H4;     // Higher Timeframe
input ENUM_TIMEFRAMES LTF_Period = PERIOD_M15;    // Lower Timeframe

input group "Strategy Parameters"
input int EMA_Period = 200;                      // HTF EMA Period
input int Breakout_Period = 20;                  // LTF Breakout Lookback Period
input int ATR_Period = 14;                       // ATR Period for Trailing Stop
input double ATR_Multiplier = 2.0;               // ATR Multiplier for Trailing Stop
input double Contraction_Threshold = 0.7;        // ATR Ratio for Contraction Phase
input double Expansion_Threshold = 1.3;          // ATR Ratio for Expansion Phase
input double Risk_Percent = 1.0;                 // Risk per Trade (% of Free Margin)
input double TP_Ratio = 2.0;                     // Take Profit Ratio (TP:SL)
input double SL_Pips = 50.0;                     // Stop Loss in Pips

input group "Trade Settings"
input double Lot_Size = 0.1;                     // Default Lot Size
input int Max_Trades = 1;                        // Max Open Trades
input int Magic_Number = 123456;                 // Magic Number
input string Trade_Comment = "MasterPatternEA";   // Trade Comment

input group             "Money management settings"
input bool                 enableMM                = true; // Enable money management setting
input double               inpMinimallotsize       = 0.01; // minimal lot size
input double               FirstBalance            = 1000; // First balance (maximum risk by trade)
input double               SecondBalance           = 2000; // Second balance (use minimal risk by trade)
input double               riskByTrade             = 0.20; // Maximum risk by trade if balance is under 1rstBalance
input double               minRiskByTrade          = 0.05; // Minimum risk by trade if balance is over 2nd balance
input double               inpStopLossPoints       = 100;  // Stop loss points
input double               maximalDailyLoss        = 0.3;  // Maximal authorized daily loss ( will stop for the rest of the day )

//--- Global Variables
double pipValue;
int emaHandleHTF, atrHandleHTF;
int barsHTF, barsLTF;
double emaBuffer[], atrBuffer[];
datetime lastBarHTF, lastBarLTF;
string currentPhase = "Unknown";
double AdaptiveRiskByTrade = riskByTrade;
double lotsize = inpMinimallotsize;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Adjust pip value for symbol
   pipValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(_Digits == 3 || _Digits == 5) pipValue *= 10;

   // Initialize EMA handle for HTF
   emaHandleHTF = iMA(_Symbol, HTF_Period, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandleHTF == INVALID_HANDLE)
   {
      Print("Failed to create EMA handle for HTF");
      return(INIT_FAILED);
   }

   // Initialize ATR handle for HTF
   atrHandleHTF = iATR(_Symbol, HTF_Period, ATR_Period);
   if(atrHandleHTF == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle for HTF");
      return(INIT_FAILED);
   }

   ArraySetAsSeries(emaBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   
   // Initialize trade object
   OnInitTrade();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(emaHandleHTF != INVALID_HANDLE) IndicatorRelease(emaHandleHTF);
   if(atrHandleHTF != INVALID_HANDLE) IndicatorRelease(atrHandleHTF);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar on LTF
   datetime currentBarLTF = iTime(_Symbol, LTF_Period, 0);
   if(currentBarLTF != lastBarLTF)
   {
      lastBarLTF = currentBarLTF;
      UpdatePhase();
      CheckForTrade();
   }
   
   // Update trailing stops for open positions
   UpdateTrailingStop();
}

//+------------------------------------------------------------------+
//| Update Master Pattern phase                                        |
//+------------------------------------------------------------------+
void UpdatePhase()
{
   // Copy ATR data
   if(CopyIndicatorBuffer(atrHandleHTF, 0, 1, 10, atrBuffer) < 10) return;
   
   // Calculate average ATR over lookback period
   double avgATR = 0;
   for(int i = 1; i < 10; i++) avgATR += atrBuffer[i];
   avgATR /= 9;
   
   // Determine phase
   double currentATR = atrBuffer[0];
   double atrRatio = currentATR / avgATR;
   
   if(atrRatio < Contraction_Threshold)
      currentPhase = "Contraction";
   else if(atrRatio > Expansion_Threshold)
      currentPhase = "Expansion";
   else
   {
      double priceClose = iClose(_Symbol, HTF_Period, 1);
      if(CopyIndicatorBuffer(emaHandleHTF, 0, 1, 3, emaBuffer) >= 3)
      {
         if(priceClose > emaBuffer[0] || priceClose < emaBuffer[0])
            currentPhase = "Trend";
         else
            currentPhase = "Neutral";
      }
   }
   
   // Display phase on chart
   Comment("Master Pattern Phase: ", currentPhase);
}

//+------------------------------------------------------------------+
//| Check for trading signals                                          |
//+------------------------------------------------------------------+
void CheckForTrade()
{
   // Get HTF trend direction
   if(CopyIndicatorBuffer(emaHandleHTF, 0, 1, 3, emaBuffer) < 3) return;
   double priceClose = iClose(_Symbol, HTF_Period, 1);
   bool isBullish = priceClose > emaBuffer[0];
   bool isBearish = priceClose < emaBuffer[0];

   // Only trade in Expansion or Trend phases
   if(currentPhase != "Expansion" && currentPhase != "Trend") return;

   // Get LTF breakout signal
   double highLTF = iHigh(_Symbol, LTF_Period, iHighest(_Symbol, LTF_Period, MODE_HIGH, Breakout_Period, 1));
   double lowLTF = iLow(_Symbol, LTF_Period, iLowest(_Symbol, LTF_Period, MODE_LOW, Breakout_Period, 1));
   double currentPrice = iClose(_Symbol, LTF_Period, 0);

   // Count open trades
   int openTrades = CountOpenTrades();
   if(openTrades >= Max_Trades) return;

   // Calculate position size based on risk
   double slPips = SL_Pips * pipValue;
   double lotSize = CalculateLotSize(slPips);

   // Buy signal: Price breaks high in uptrend
   if(isBullish && currentPrice > highLTF && openTrades < Max_Trades)
   {
      double sl = currentPrice - slPips;
      double tp = currentPrice + (slPips * TP_Ratio);
      trade.Buy(lotSize, _Symbol, currentPrice, sl, tp, Trade_Comment);
   }

   // Sell signal: Price breaks low in downtrend
   if(isBearish && currentPrice < lowLTF && openTrades < Max_Trades)
   {
      double sl = currentPrice + slPips;
      double tp = currentPrice - (slPips * TP_Ratio);
      trade.Sell(lotSize, _Symbol, currentPrice, sl, tp, Trade_Comment);
   }
}

//+------------------------------------------------------------------+
//| Update trailing stop based on ATR                                 |
//+------------------------------------------------------------------+
void UpdateTrailingStop()
{
   double atrValue = 0;
   if(CopyIndicatorBuffer(atrHandleHTF, 0, 0, 1, atrBuffer) >= 1)
      atrValue = atrBuffer[0] * ATR_Multiplier;
   else return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            long positionType = PositionGetInteger(POSITION_TYPE);

            if(positionType == POSITION_TYPE_BUY)
            {
               double newSL = currentPrice - atrValue;
               if(newSL > sl && newSL < currentPrice)
                  trade.PositionModify(ticket, newSL, tp);
            }
            else if(positionType == POSITION_TYPE_SELL)
            {
               double newSL = currentPrice + atrValue;
               if(newSL < sl && newSL > currentPrice)
                  trade.PositionModify(ticket, newSL, tp);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Copy indicator buffer                                             |
//+------------------------------------------------------------------+
int CopyIndicatorBuffer(int handle, int buffer, int start, int count, double &data[])
{
   ArrayResize(data, count);
   return CopyBuffer(handle, buffer, start, count, data);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPips)
{
  {
   double availableCash = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(enableMM == false)
     {
      return inpMinimallotsize;
     }

   if(availableCash > FirstBalance)
     {
      // Linear interpolation: risk = initial_risk - (balance - min_balance) * slope
      double slope = (riskByTrade - minRiskByTrade) / (SecondBalance - FirstBalance);
      AdaptiveRiskByTrade = riskByTrade- (availableCash - FirstBalance) * slope;
      AdaptiveRiskByTrade = MathMax(minRiskByTrade, MathMin(riskByTrade, AdaptiveRiskByTrade));
     }




   double riskAmount =   AccountInfoDouble(ACCOUNT_MARGIN_FREE) * AdaptiveRiskByTrade;

// Get symbol-specific pip value per lot
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pipValuePerLot;

// Estimate pip value (assuming 1 pip = 10 points for Forex)
   if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 2 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 4)
      pipValuePerLot = tickValue; // 1 pip = 1 point
   else
      pipValuePerLot = tickValue * 10.0; // 1 pip = 10 points

// Calculate raw lot size
   lotsize = riskAmount / (inpStopLossPoints * (pipValuePerLot*10.0));

// Round down to nearest 0.01
   lotsize = MathFloor(lotsize * 100.0) / 100.0;
// Ensure minimum lot size
   return MathMax(lotsize, inpMinimallotsize);
  }
//+------------------------------------------------------------------+
}

//+------------------------------------------------------------------+
//| Count open trades                                                 |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == Magic_Number)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Trade object for MQL5                                             |
//+------------------------------------------------------------------+
CTrade trade;
void OnInitTrade()
{
   trade.SetExpertMagicNumber(Magic_Number);
}