//+------------------------------------------------------------------+
//|                                                     OBStruct.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

enum NoTradeReason
  {
      ENUM_REASON_INIT, // No problem, trade can be filled
      ENUM_NO_REASON, // No problem, trade can be filled
      ENUM_REASON_IS_OVERDUE, // overdue
      ENUM_REASON_IS_OVEEXTENDED, // overdue
      ENUM_LACK_STARS, // need 3 stars
      ENUM_REASON_IMBALANCED_NOT_FILLED, // Imbalanced is not filled 
      ENUM_REASON_IMBALANCED_FILLED, // Imbalanced filled 
      ENUM_REASON_NO_LIQUIDITY_SWEPT_BEFORE, //  No liquidity swept before OB
      ENUM_REASON_DISTRIBUION_WYCKOFF, // Distribution detected
      ENUM_REASON_ACCUMULATION_WYCKOFF, // Accumulation detected
      ENUM_REASON_NO_ENOUGH_FUND, // No enough fund to realize the trade
      ENUM_REASON_LOWER_FAST_MA, // Price is lower than Fast moving average
      ENUM_REASON_HIGHER_FAST_MA, // Prise is Higher than Fast moving average
      ENUM_REASON_LOWER_SLOW_MA, // Price is lower than Slow moving average
      ENUM_REASON_HIGHER_SLOW_MA, // Prise is Higher than Slow moving average
      ENUM_REASON_ISDONE, // Order Block is Done, soon deleted
      ENUM_REASON_ISMITIGATED, // Order Block is mitigated
      ENUM_REASON_IS_NOT_PREMIUM, // Bearish Order Block is not in the Premium zone
      ENUM_REASON_IS_NOT_DISCOUNT, // Bullish Order Block is not in the Discount zone
      ENUM_REASON_IS_COUNTER_BULLISH, // counter trend
      ENUM_REASON_IS_COUNTER_BEARISH, // counter trend
      ENUM_REASON_IS_LOW_IMBALANCE, // low imbalance
      ENUM_REASON_IS_PURPLE, // there is a previous OB
      ENUM_REASON_TREND_RANGE_PROTECTION, // trend is range so protection enabled
      ENUM_REASON_DONE, // done with TP or SL
      ENUM_NOT_CROSSED_127,
      ENUM_NOT_CROSSED_50,
  };

struct orderBlock
  {

   string            name;
   int               index;
   datetime          startTime;
   double            entryPrice;
   datetime          entryTime;
   double            highPrice;
   double            lowPrice;
   double            imbalancePrice;
   bool              isMitigated;
   bool              isBOS;
   bool              DoTrailing;
   bool              DoRevengeTrailing;
   bool              sweepRevenge;
   bool              HasSweepBefore;
   datetime          mitigatedTime;
   double            mitigatedLine;
   bool              isImbalanced;
   bool              ImbalancedFilled;
   double            imbalancedDist;
   bool              isBear;
   int               stars;
   long              OBcolor;
   bool              isDone;
   double            highLiquid;
   double            lowLiquid;
   double            OBBody, OBWick;
   double            fibn027; // sl
   double            fib50; // entry price
   double            fib80, fib100, fib140; // if reach, sl is move to entry point + comission + spread, TP is moved to next tp level fib161 -> 238
   double            fib127, fib1618, fib200, fib23812, fibLimit; // to validate rehearsal as enough
   datetime          prevlowi, prevhighi;
   bool              cross127, cross161,cross238,cross50;
   short             trendDir;
   int               hasParent;
   ulong             tradeTicket;
   ulong             revengeTicket;
   ulong             lightBuzzTicket;
   bool              dolightbuzzTrailing;
   bool              isLightbuzz;
   bool              isrevenge;
   double            takeProfit;
   double            stopLoss;
   double            stoplossDistance;
   bool              is1R;
   
   NoTradeReason     reason;


   bool              isInsideHTFOB()
     {
   /*   if(this.hasParent > 0)
         return true;

      int parentOB = -1;

      // Get the higher timeframe candle that contains the 6-minute candle
      int shift = iBarShift(_Symbol, HTOB, startTime, false) ;
      if(shift < 0)
        {
         Print("Error: Could not find corresponding bar in higher timeframe. Error code: ", GetLastError());
         return false;
        }

      MqlRates initHTFHa[];
      int HtflookBackPeriod = shift + 30;
      ArrayResize(initHTFHa, HtflookBackPeriod);
      CopyRates(_Symbol,HTOB,0,HtflookBackPeriod,initHTFHa);
      for(int a = 0; a < HtflookBackPeriod ; a++)
        {
         ArrayCopy(hA, initHTFHa, 0, a, 5);
         if(HTFalreadyFound() == false)
           {
            parentOB = detectHTFOB();
            if(parentOB > -1)
               break;
           }
        }


      if(parentOB > -1)
        {

         // Assume order block detection logic (customize as per your EA's definition)
         // Example: Bullish order block (close > open and significant move)
         bool isHTBullishOB = HTobBuffer[parentOB].isBear;
         bool isHTBearishOB = HTobBuffer[parentOB].isBear;

         // Check if the 6-minute order block is within the higher timeframe candle's range
         bool isWithinRange = (HTobBuffer[parentOB].fib50 <= this.entryPrice && this.entryPrice >= HTobBuffer[parentOB].highPrice) ? true : false;

         // Additional condition: Ensure the order block types match (e.g., both bullish or both bearish)
         // Modify this based on your order block definition
         bool isValidOB = false;
         if(isWithinRange == true )
           {
            // Example: Assume 6-minute block is bullish if high6Min > low6Min (simplified)
            bool is6MinBearish = this.isBear; // Replace with your actual logic
            if(is6MinBearish == false && isHTBullishOB == false)
              {
               isValidOB = true; // Bullish 6-min block within bullish HTF block
              }
            else
               if(is6MinBearish == true && isHTBearishOB == true)
                 {
                  isValidOB = true; // Bearish 6-min block within bearish HTF block
                 }
           }

         if(isValidOB == true )
           {
            Print("Order block on 6-min timeframe at ", TimeToString(startTime),
                  " is part of a higher timeframe order block at ", TimeToString(HTobBuffer[parentOB].startTime));
            this.stars = this.stars + 1;
            this.hasParent = parentOB;
            return true;
           }
        }
*/
      return false;


     }

   void              init(string myName,int myIndex, datetime startT,
                          double highP,double lowP, double OBBdy, double lastCandlesWick, bool bear = false,
                          long oC = clrBlue, bool isHTFOB = false)
     {

      name = myName;
      reason = ENUM_REASON_INIT;
      startTime = startT;
      index= myIndex;
      highPrice = highP;
      lowPrice  = lowP;
      stars= 1; // because has minimal body
      isBear = bear;
      revengeTicket = 0;
      ImbalancedFilled = false;
      lightBuzzTicket = 0;
      sweepRevenge= false;
      isMitigated = false;
      isImbalanced= false;
      isLightbuzz = false;
      is1R        = false;
      hasParent = -1;
      isDone=false;
      isBOS= false;
      DoTrailing = false;
      OBcolor = oC;
      trendDir = trendDirection;
      //stars = (trendDirection == 1 && isBear == false) ? stars + 1 : 0;
      //stars = (trendDirection == -1 && isBear == true) ? stars + 1 : 0;
      OBBody = OBBdy;
      OBWick = lastCandlesWick;

      getFibLevels(myIndex);

      stoplossDistance = MathAbs(fib50 - fibn027) * _Point;

      cross127    = false;
      cross161    = false;
      cross238    = false;
      cross50     = false;

      mitigatedLine = (highPrice + lowPrice) / 2;
      if ( TerminalInfoInteger(TERMINAL_VPS) == 1){
         Print("A new Order Block is detected " );
      }
      if(isHTFOB == false)
        {
         if(isFirstOB(myIndex) == false)
           {
            OBcolor = clrPurple;
            isDone = true;
            stars = 0;
            reason = ENUM_REASON_IS_PURPLE;
           }
        }

     }

  }
//+------------------------------------------------------------------+
