//+------------------------------------------------------------------+
//|                                                  cOrderBlock.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#include "types.mqh"
#include "helpers.mqh"
#include "globals.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class cOrderBlock : public orderBlock
  {
private:
   ;
public:
   void              cOrderBlock();
   void             ~cOrderBlock();
   entryType         getAutoEntryType();
   void              addStars(int add = 1);
   bool              hasOppositeOB(bool isOpposite);
   bool              checkForMSSEntry(bool BearishMss = false, datetime start = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool              checkForCISDEntry(bool BearishMss = false, ENUM_TIMEFRAMES tf = PERIOD_CURRENT);
   bool              checkForMSSBefore(int lookback = 15);
   datetime          checkForCrossLiquidity(datetime mssLastLeg, int candlesBack = 20, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, ENUM_TIMEFRAMES origintf = PERIOD_CURRENT, bool strict = true);
   bool              hasCounterChoch();
   void              init(int myIndex, datetime startT,
                          double highP, double lowP, double OBBdy, double lastCandlesWick, bool bear = false,
                          long oC = clrBlue, bool isHTFOB = false);
   double            getMaxImpulsion();
   double            GetCurrentRR();
   double            getRR();
   bool              getTPByRRR(double rrr);
   bool              getTPByChange(double percent);
   bool              PriceNearExpansion(double expansionLevel,
                                        double tolerancePips = 5.0);
   bool              PartialClose(double percent);
   void              ManagePartialTP();
   bool              checkValidLssc();
   bool              CheckOBBreakerBlock();
   bool              checkValidImbalance();
   bool              checkLiquiditySweepBeforeOB(datetime mssLeg, int lookBack = 80);
   bool              IsFairValueGapFilled();
   bool              checkInZone();
   bool              isAllGood(int i);
   bool              isMinQuality();
   void              trashme(NoTradeReason r);
   bool              IsIndexValid(int index, orderBlock &array[]);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
cOrderBlock::cOrderBlock()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
cOrderBlock::~cOrderBlock()
  {
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
entryType cOrderBlock::getAutoEntryType()
  {
   double obSize = MathAbs(OBBody - OBWick);
   if(imbalancedDist < obSize * 0.25)
     {
      fib50      = open(iBarShift(_Symbol, CTOB, startTime));
      entryPrice = imbalancePrice;
      return ENUM_ENTRY_OBOPEN;   // FVG petit → entrée agressive
     }
   else
     {
      if(imbalancedDist < obSize * 0.75)
        {
         fib50      = open(iBarShift(_Symbol, CTOB, startTime)) + ((open(iBarShift(_Symbol, CTOB, startTime)) - close(iBarShift(_Symbol, CTOB, startTime))) / 2);
         entryPrice = imbalancePrice;
         return ENUM_ENTRY_F50;   // FVG moyen → entrée médiane
        }
      else
        {
         fib50      = imbalancePrice;
         entryPrice = imbalancePrice;
         return ENUM_ENTRY_FVG;   // FVG profond → entrée FVG
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void cOrderBlock::addStars(int add = 1)
  {
   stars = stars + add;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::hasOppositeOB(bool isOpposite)
  {
   int distance = iBarShift(_Symbol, CTOB, startTime);
   if(isBear != isOpposite &&
      (isDone == false || distance > 20 || OBcolor != clrGreen) &&
      stars >= 3)
     {
      Print("Opposite OrderBlock detected while trying to open a trade. Current order is done");
      isDone = true;
      reason = ENUM_REASON_OPPOSITE_OB;
      stars  = 0;

      if(tradeTicket != INVALID_TICKET)
        {
         CancelPendingIfExists(tradeTicket);
         tradeTicket = INVALID_TICKET;
        }

      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|          Check for MSS entry ( if auto mode )                    |
//|          rules : bullish market, check the last bearish candle
//|                  wich make an higher low and break ob impulsion
//|                  or a displacement, has to be bellow sell side
//|                  liquidity
//|
//|                  bearish market, check the last bullish candle
//|                  wich make an higher high and break ob impulsion
//|                  or a displacement, has to be above buy side
//|                  liquidity
//|
//|         MSS bearish : ^ casse par impulse / MSS Bullish : V casse par impulse
//+------------------------------------------------------------------+
bool cOrderBlock::checkForMSSEntry(bool BearishMss = false, datetime start = 0, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
  {
   int    startIndex         = iBarShift(_Symbol, CTOB, start);
   int    lookback           = 20;
   int    breakerLimit       = 0;
   double MSSLowerBreakLevel = -1.0;
   double currentHigh        = -1.0;
   double currentLow         = -1.0;
   string mssName            = "lower";

   if(isMSS == true || MSSMandatory == false)
     {
      lookback = bar(topImpTime, tf);
      startIndex++;   // so the current candle can t be the first high
     }

   datetime lastLowTime   = 0;
   datetime lastHighTime  = 0;
   datetime firstLowTime  = 0;
   datetime firstHighTime = 0;

   double lastLowLevel   = -1.0;
   double lastHighLevel  = -1.0;
   double firstLowLevel  = -1.0;
   double firstHighLevel = -1.0;

   int distance = -1;
   // OPTI: ChartSetSymbolPeriod triggers a chart redraw — skip in backtests
   if(!MQL_TESTER)
      ChartSetSymbolPeriod(0, _Symbol, tf);

// step 1 on cherche un mss dans le sens de l ob : ob bearish on cherche un mss bearish
// step 2 on cherche un mss bullish apres le reversal. donc ob bearish => on cherche un mss bullish
   if(BearishMss == false)
     {
      // we check the first swing low from the starttime
      lastLowLevel     = GetLastSwingLow(startIndex, lookback, lastLowTime, tf, true, true);
      int lastLowIndex = iBarShift(_Symbol, tf, lastLowTime, true);

      if(lastLowTime == 0 || lastLowLevel == -1.0)
         return false;

      // then we check the last swing high
      lastHighLevel     = GetLastSwingHigh(lastLowIndex + 1, lookback, lastHighTime, tf, true);
      int lastHighIndex = iBarShift(_Symbol, tf, lastHighTime, true);
      // MSS level
      if(lastHighTime == 0 || lastHighLevel == -1.0)
         return false;

      // we check for the first swing low
      firstLowLevel     = GetLastSwingLow(lastHighIndex + 1, lookback, firstLowTime, tf, true);
      int firstLowIndex = iBarShift(_Symbol, tf, firstLowTime, true);

      if(firstLowTime == 0 || firstLowLevel == -1.0)
         return false;

      if(firstLowLevel <= lastLowLevel)
        {
         return false;
        }

      int a              = 1;
      MSSLowerBreakLevel = (isBullishCandle(a) == true) ? close(a, tf) : open(a, tf);
      MSSLowerStart      = lastHighTime;
      MSSLowerLevel      = lastHighLevel;
      if(MSSLowerBreakLevel > MSSLowerLevel &&
         lastLowIndex > a &&
         detectFVG(a, true, MSSLowerLevel, tf) == true)
        {
         if(isLowerMss == false)
           {
            addStars();
            entryPrice  = Ask();
            MSSLowerEnd = time(a, tf);
            drawSwingPoint(name + "-MSS-low-" + TimeToString(MSSLowerStart), MSSLowerStart, MSSLowerLevel, 77, clrBlue, -1, "MSS-low");
            drawBreakLevel(name + "-mss-low-break" + TimeToString(MSSLowerEnd), MSSLowerStart, MSSLowerLevel,
                           MSSLowerEnd, MSSLowerLevel, clrBlue, -1);

            isLowerMss = true;
            finalCheck = 10;
            return isLowerMss;
           }
        }
     }

   if(BearishMss == true)
     {

      // we check the first swing low from the starttime
      lastHighLevel     = GetLastSwingHigh(startIndex, lookback, lastHighTime, tf, true, true);
      int lastHighIndex = iBarShift(_Symbol, tf, lastHighTime, true);

      if(lastHighTime == 0 || lastHighLevel == -1.0)
         return false;

      // then we check the last swing high MSS LEVEL
      lastLowLevel     = GetLastSwingLow(lastHighIndex + 1, lookback, lastLowTime, tf, true);
      int lastLowIndex = iBarShift(_Symbol, tf, lastLowTime, true);

      if(lastLowTime == 0 || lastLowLevel == -1.0)
         return false;

      // we check for the first swing High
      firstHighLevel     = GetLastSwingHigh(lastLowIndex + 1, lookback, firstHighTime, tf, true);
      int firstHighIndex = iBarShift(_Symbol, tf, firstHighTime, true);

      if(firstHighTime == 0 || firstHighLevel == -1.0)
         return false;

      if(firstHighLevel >= lastHighLevel)
        {
         return false;
        }

      // OpenCL candidate: backward scan over candles. If many such scans are
      // performed in bulk (different objects/timeframes), consider a kernel that
      // checks conditions per-candle in parallel. Keep this CPU loop for legacy.
      // ── GPU-accelerated: pre-filter bars by break-level, FVG check on CPU hits only
        MSSLowerStart = lastLowTime;
        MSSLowerLevel = lastLowLevel;
        int      gpu_flags[];
        bool     gpu_ok = GPU_GetMSSBreakFlags(lastHighIndex, lastLowLevel, true, lastLowIndex, tf, gpu_flags);
        for(int a = lastHighIndex; a >= 0; a--)
          {
           // CPU fallback: evaluate break condition here; GPU path: use pre-computed flag
           if(gpu_ok)
             {
              if(a >= ArraySize(gpu_flags) || gpu_flags[a] == 0) continue;
             }
           else
             {
              MSSLowerBreakLevel = (isBullishCandle(a) == false) ? close(a, tf) : open(a, tf);
              if(!(MSSLowerBreakLevel < MSSLowerLevel && lastLowIndex > a)) continue;
             }
           if(detectFVG(a, true, MSSLowerStart, tf) == true)
             {
              if(isLowerMss == false)
                {
                 addStars();
                 entryPrice  = Bid();
                 MSSLowerEnd = time(a, tf);
                 drawSwingPoint(name + "-MSS-lower" + TimeToString(MSSLowerStart), MSSLowerStart, MSSLowerLevel, 77, clrRed, -1, "MSS");
                 drawBreakLevel(name + "-mss-lower-break" + TimeToString(MSSLowerEnd), MSSLowerStart, MSSLowerLevel,
                                MSSLowerEnd, MSSLowerLevel, clrRed, -1);

                 isLowerMss = true;
                 finalCheck = 10;
                 return isLowerMss;
                }
             }
          }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|            search for MSS that created the OB                    |
//| ob bullish = mss bearish | ob bearish = mss bullish
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CISD Entry: wait for retest of the LTF MSS break level          |
//| After MSS is detected (isLowerMss=true), this function confirms  |
//| entry on a pullback candle that touches MSSLowerLevel from the   |
//| correct side and shows a reaction (Change in State of Delivery). |
//+------------------------------------------------------------------+
bool cOrderBlock::checkForCISDEntry(bool BearishMss = false, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
  {
   if(isCISD == true)
      return true;

   if(MSSLowerLevel <= 0)
      return false;

   double _atr       = getAtr(14, tf);
   double _tolerance = 0.3 * _atr;
   double minBody   = 0.25 * _atr;   // require meaningful reaction candle

   if(BearishMss == false)
     {
      // Bullish OB: look for a post-MSS candle that dips to/below MSSLowerLevel and closes above it
      for(int a = 1; a <= 8; a++)
        {
         // only inspect candles that formed AFTER the MSS break was confirmed
         if(MSSLowerEnd > 0 && time(a, tf) <= MSSLowerEnd)
            break;
         double lo   = low(a, tf);
         double cl   = close(a, tf);
         double op   = open(a, tf);
         double body = cl - op;
         if(lo <= MSSLowerLevel + tolerance &&
            cl > MSSLowerLevel &&
            body >= minBody)   // bullish reaction with real body
           {
            isCISD     = true;
            finalCheck = 11;
            return true;
           }
        }
     }
   else
     {
      // Bearish OB: look for a post-MSS candle that spikes to/above MSSLowerLevel and closes below it
      for(int a = 1; a <= 8; a++)
        {
         if(MSSLowerEnd > 0 && time(a, tf) <= MSSLowerEnd)
            break;
         double hi   = high(a, tf);
         double cl   = close(a, tf);
         double op   = open(a, tf);
         double body = op - cl;
         if(hi >= MSSLowerLevel - tolerance &&
            cl < MSSLowerLevel &&
            body >= minBody)   // bearish reaction with real body
           {
            isCISD     = true;
            finalCheck = 11;
            return true;
           }
        }
     }

   return false;
  }

bool cOrderBlock::checkForMSSBefore(int lookback = 15)
  {
   if(isMSS == true)
      return true;

   datetime lastLowTime   = 0;
   datetime lastHighTime  = 0;
   datetime firstLowTime  = 0;
   datetime firstHighTime = 0;

   double lastLowLevel   = -1.0;
   double lastHighLevel  = -1.0;
   double firstLowLevel  = -1.0;
   double firstHighLevel = -1.0;

   double MSSBreakLevel = -1.0;
   int    startIndex    = bar(startTime);

   if(startIndex >= 100)
     {
      trashme(ENUM_REASON_NO_MSS);
      return false;
     }

// if ob is bullish we look for a bearish mss ( 1 l , 1 h , 1 l , break displacement )
   if(isBear == false)   // => MSS BEARISH
     {
      // last low is startindex
      lastLowLevel     = low(startIndex);
      lastLowTime      = startTime;
      int lastLowIndex = startIndex;

      if(low(startIndex) > low(startIndex - 1))
        {
         lastLowIndex = startIndex - 1;
         lastLowLevel = low(lastLowIndex);
         lastLowTime  = time(lastLowIndex);
        }

      if(lastLowTime == 0 || lastLowLevel == -1.0)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      // then we check the last swing high
      lastHighLevel     = GetLastSwingHigh(lastLowIndex + 1, lookback, lastHighTime, CTOB, true);
      int lastHighIndex = iBarShift(_Symbol, CTOB, lastHighTime, true);
      // MSS level
      if(lastHighTime == 0 || lastHighLevel == -1.0)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      // we check for the first lowest swing low == true 6th parameter
      firstLowLevel     = GetLastSwingLow(lastHighIndex + 1, lookback, firstLowTime, CTOB, true, true);
      int firstLowIndex = iBarShift(_Symbol, CTOB, firstLowTime, true);

      if(firstLowTime == 0 || firstLowLevel == -1.0)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      double lastBodyLevel = (isBullishCandle(lastLowIndex) == true) ? open(lastLowIndex) : close(lastLowIndex);
      if(firstLowLevel < lastBodyLevel)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      MSSFirst = firstLowTime;
      MSSStart = lastHighTime;
      MSSLevel = lastHighLevel;

      if(inpRequireSweep && checkLiquiditySweepBeforeOB(lastLowTime) == false)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      if(lastLowLevel > dpMid)
        {
         trashme(ENUM_REASON_IS_NOT_DISCOUNT);
         return false;
        }

      int lastCandleCheck = (MSSLastCandleChecked == 0) ? lastLowIndex : bar(MSSLastCandleChecked, CTOB);
      if(lastCandleCheck > 30)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      for(int a = lastCandleCheck; a >= 0; a--)
        {
         MSSBreakLevel        = (isBullishCandle(a) == true) ? close(a, CTOB) : open(a, CTOB);
         MSSLastCandleChecked = time(a, CTOB);

         if(MSSBreakLevel > MSSLevel &&
            (inpMSSRequireFVG == false || detectFVG(a, true, MSSLevel, CTOB) == true) &&
            lastLowIndex > a)
           {
            if(isMSS == false)
              {
               addStars();
               checkedMSS = true;
               MSSEnd     = time(a, CTOB);
               drawSwingPoint(name + "-MSS-" + TimeToString(MSSStart), MSSStart, MSSLevel, 77, clrBlue, -1, "MSS");
               drawBreakLevel(name + "-mss-break" + TimeToString(MSSEnd), MSSStart, MSSLevel,
                              MSSEnd, MSSLevel, clrBlue, -1);

               isMSS      = true;
               reason     = ENUM_HAS_MSS;
               finalCheck = 4;
               return isMSS;
              }
           }
        }
     }

// if ob is bearish we look for a bullish mss ( 1 h , 1 l , 1 h , break displacement )
   if(isBear == true)
     {

      // we check the first swing low from the starttime
      lastHighLevel     = (high(startIndex) < high(startIndex - 1)) ? high(startIndex) : high(startIndex - 1);
      lastHighTime      = startTime;
      int lastHighIndex = startIndex;

      if(high(startIndex) < high(startIndex - 1))
        {
         lastHighIndex = startIndex - 1;
         lastHighLevel = high(lastHighIndex);
         lastHighTime  = time(lastHighIndex);
        }

      if(lastHighTime == 0 || lastHighLevel == -1.0)
        {
         // trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      // then we check the last swing high MSS LEVEL
      lastLowLevel     = GetLastSwingLow(lastHighIndex + 1, lookback, lastLowTime, CTOB, true);
      int lastLowIndex = iBarShift(_Symbol, CTOB, lastLowTime, true);

      if(lastLowTime == 0 || lastLowLevel == -1.0)
        {
         // trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      // we check for the first highest swing low == true 6th parameter
      firstHighLevel     = GetLastSwingHigh(lastLowIndex + 1, lookback, firstHighTime, CTOB, true, true);
      int firstHighIndex = iBarShift(_Symbol, CTOB, firstHighTime, true);

      if(firstHighTime == 0 || firstHighLevel == -1.0)
        {
         // trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      double lastBodyLevel = (isBullishCandle(lastHighIndex) == true) ? open(lastHighIndex) : close(lastHighIndex);
      if(firstHighLevel > lastBodyLevel)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      MSSFirst = firstHighTime;
      MSSStart = lastLowTime;
      MSSLevel = lastLowLevel;

      if(inpRequireSweep && checkLiquiditySweepBeforeOB(lastHighTime) == false)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      if(lastHighLevel < dpMid)
        {

         trashme(ENUM_REASON_IS_NOT_PREMIUM);
         return false;
        }

      int lastCandleCheck = (MSSLastCandleChecked == 0) ? lastHighIndex : bar(MSSLastCandleChecked, CTOB);
      if(lastCandleCheck > 30)
        {
         trashme(ENUM_REASON_NO_MSS);
         return false;
        }

      for(int a = lastCandleCheck; a >= 0; a--)
        {
         MSSBreakLevel        = (isBullishCandle(a) == false) ? close(a, CTOB) : open(a, CTOB);
         MSSLastCandleChecked = time(a, CTOB);
         if(MSSBreakLevel < MSSLevel &&
            (inpMSSRequireFVG == false || detectFVG(a, true, MSSLevel, CTOB) == true) &&
            lastLowIndex > a)
           {
            MSSEnd = time(a, CTOB);
            if(isMSS == false)
              {
               addStars();
               MSSEnd     = time(a, CTOB);
               checkedMSS = true;
               drawSwingPoint(name + "-MSS-" + TimeToString(MSSStart), MSSStart, MSSLevel, 77, clrRed, -1, "MSS");
               drawBreakLevel(name + "-mss-break" + TimeToString(MSSEnd), MSSStart, MSSLevel,
                              MSSEnd, MSSLevel, clrRed, -1);

               isMSS      = true;
               reason     = ENUM_HAS_MSS;
               finalCheck = 4;
               return isMSS;
              }
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|   Check MSS Before OB cross a BSL / SSL                          |
//+------------------------------------------------------------------+
datetime cOrderBlock::checkForCrossLiquidity(datetime mssLastLeg, int candlesBack = 20, ENUM_TIMEFRAMES tf = PERIOD_CURRENT, ENUM_TIMEFRAMES origintf = PERIOD_CURRENT, bool strict = true)
  {
   int mssFirstLegIndex = bar(mssLastLeg, origintf);

   if(isBear == false)
     {
      // we search for a swing low
      for(int a = mssFirstLegIndex; a <= candlesBack; a++)
        {
         datetime dt;
         double   swingLowLevel = GetLastSwingLow(mssFirstLegIndex + 1, candlesBack, dt, tf, true);
         if(swingLowLevel >= low(mssFirstLegIndex, origintf))
           {
            for(int b = bar(dt - 1, tf); b < mssFirstLegIndex; b--)
              {
               if(low(b, tf) <= swingLowLevel)
                  break;   // liquidity already taken
              }
            return dt;
           }
        }
     }
   if(isBear == true)
     {
      // we search for a swing high
      for(int a = mssFirstLegIndex; a <= candlesBack; a++)
        {
         datetime dt;
         double   swingHighLevel = GetLastSwingHigh(mssFirstLegIndex + 1, candlesBack, dt, tf, true);
         if(swingHighLevel <= high(mssFirstLegIndex, origintf))
           {
            for(int b = bar(dt - 1, tf); b < mssFirstLegIndex; b--)
              {
               if(high(b, tf) >= swingHighLevel)
                  break;   // liquidity already taken
              }
            return dt;
           }
        }
     }

   if(strict == true)
     {
      stars  = 0;
      isDone = true;
     }
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::hasCounterChoch()
  {
   int      countBack = 20;
   datetime lslTime;
   datetime lshTime;
   int      startIndex    = iBarShift(_Symbol, CTOB, startTime);
   double   lastSwingLow  = GetLastSwingLow(startIndex, countBack, lslTime, true, CTOB);
   double   lastSwingHigh = GetLastSwingHigh(startIndex, countBack, lshTime, true, CTOB);

   int      previousLIndex = iBarShift(_Symbol, CTOB, lslTime) + 5;
   datetime previousLTime;
   double   previousLow = GetLastSwingLow(previousLIndex, countBack, previousLTime, true, CTOB);

   int      previousHIndex = iBarShift(_Symbol, CTOB, lshTime) + 5;
   datetime previousHTime;
   double   previousHigh = GetLastSwingHigh(previousHIndex, countBack, previousHTime, true, CTOB);

   if(previousLow > lastSwingLow &&
      previousLow < DBL_MAX &&
      isBear == false)
     {
      hasChoch = true;
      isDone   = true;
      stars    = 0;
      return true;
     }

   if(previousHigh < lastSwingLow &&
      previousHigh > -DBL_MAX &&
      isBear == true)
     {
      hasChoch = true;
      isDone   = true;
      stars    = 0;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void cOrderBlock::init(int myIndex, datetime startT,
                       double highP, double lowP, double OBBdy, double lastCandlesWick, bool bear = false,
                       long oC = clrBlue, bool isHTFOB = false)
  {

   name                 = "ICT_OB" + TimeToString(startT, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   reason               = ENUM_REASON_INIT;
   startTime            = startT;
   isContinuationTrap   = false;
   index                = myIndex;
   highPrice            = highP;   //
   lowPrice             = lowP;
   stars                = 0;   // because has minimal body
   isBear               = bear;
   revengeTicket        = INVALID_TICKET;
   tradeTicket          = INVALID_TICKET;
   ImbalancedFilled     = false;
   lightBuzzTicket      = 0;
   sweepRevenge         = false;
   isMitigated          = false;
   hasInducement        = false;
   isImbalanced         = false;
   imbalancePrice       = -1.0;
   isLightbuzz          = false;
   is1R                 = false;
   hasChoch             = false;
   hasFibLevel          = false;
   isStat               = false;
   MSSFirst             = 0;
   MSSLastCandleChecked = 0;
   MSSStart             = 0;
   MSSEnd               = 0;
   MSSLowerFirst        = 0;
   isMSS                = false;
   isLowerMss           = false;
   onHold               = false;
   hasParent            = -1;
   isDone               = false;
   isBOS                = false;
   lsscValid            = false;
   BOSLevel             = -1.0;
   sweepLevel           = -1.0;
   DoTrailing           = false;
   OBcolor              = oC;
   lotSize              = -1.0;
   trendDir             = mHTFTrend;
   sqlID                = -42;
   OBBody               = OBBdy;
   OBWick               = lastCandlesWick;
   FVGStart             = -1;
   FVGEnd               = -1;
   FVGStartLevel        = -1;
   FVGEndLevel          = -1;

   lssc      = 0;
   lsscPrice = -1.0;

   cross127  = false;
   cross161  = false;
   cross238  = false;
   cross50   = false;
   allChecks = false;
   checkedLS = false;

   BOSLevel       = -1.0;
   topImpLevel    = -1.0;
   topImpTime     = 0;
   topImpValid    = false;
   isBreakerBlock = false;
   entryPrice     = -1.0;
   stopLoss       = -1.0;
   takeProfit     = -1.0;
   PartialDone    = false;
   isZoneValid    = false;
   isMulti        = false;
   isBFW          = false;
   HasSweepBefore = false;
   finalCheck     = 0;
   wasRange       = false;

   if(tslTrigger == TLS_TRIGGER_ALWAYS)
     {
      DoTrailing = true;
     }
   if(hasInducement == false)
      displayInducement();

   if(sqlID == -42)
      sqlID = sql.insertOB(obBuffer[myIndex]);
   int size = ArraySize(reasonBuffer);
   ArrayResize(reasonBuffer, size + 1);
   reasonBuffer[size] = obBuffer[myIndex].name + "-StatusReason";

   if(lssc == 0 && lsscPrice == -1.0)
     {
      lssc           = getlastSameSideCandle(isBear, startTime, CTOB);
      lsscPrice      = open(bar(lssc));
      double lowSide = lowPrice;

      if(lssc != startTime)
        {
         lsscPrice = open(bar(lssc, CTOB), CTOB);
         lowSide   = (isBear == false) ? low(bar(startTime)) : high(bar(startTime));
         isMulti   = true;
        }

      mitigatedLine = (lsscPrice + lowSide) / 2;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double cOrderBlock::getMaxImpulsion()
  {
   if(topImpValid == true)
      return topImpLevel;

   int startIndex = iBarShift(_Symbol, CTOB, startTime);

// bullish
   if(isBear == false)
     {
      int idx     = iHighest(_Symbol, CTOB, MODE_HIGH, startIndex, 0);
      topImpLevel = high(idx);
      topImpTime  = time(idx);
     }
   if(isBear == true)
     {
      int idx     = iLowest(_Symbol, CTOB, MODE_LOW, startIndex, 0);
      topImpLevel = low(idx);
      topImpTime  = time(idx);
     }

   if(bar(topImpTime) >= 3 && topImpTime > 0)
     {
      topImpValid = true;
      finalCheck  = 9;
      return topImpLevel;   // we consider we have enough candles to check
     }
   else
     {
      return -DBL_MAX;
     }

   if(isBear == false && Ask() > OBBody && topImpTime > 0)
     {
      finalCheck = 9;
      return topImpLevel;
     }
   if(isBear == true && Bid() < OBWick && topImpTime > 0)
     {
      finalCheck = 9;
      return topImpLevel;
     }
   finalCheck = 9;
   return topImpLevel;
  }

//+------------------------------------------------------------------+
//|                          return current RR from ticket           |
//+------------------------------------------------------------------+
double cOrderBlock::GetCurrentRR()
  {
   double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double risk   = MathAbs(entryPrice - stopLoss);
   double reward = MathAbs(price - entryPrice);

   if(risk <= 0.0)
      return 0.0;

   return reward / risk;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                          return RR                               |
//+------------------------------------------------------------------+
double cOrderBlock::getRR()
  {
   double risk   = MathAbs(entryPrice - stopLoss);
   double reward = MathAbs(takeProfit - entryPrice);

   if(risk <= 0.0)
      return 0.0;

   return reward / risk;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::getTPByRRR(double rrr)
  {
   double risk = MathAbs(entryPrice - stopLoss);
   if(risk <= 0.0)
      return false;

   double reward = risk * rrr;

   if(isBear == false)
      takeProfit = entryPrice + reward;
   else
      takeProfit = entryPrice - reward;

// Normalisation au tick
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      takeProfit = NormalizeDouble(takeProfit / tickSize, 0) * tickSize;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::getTPByChange(double percent)
  {
   if(entryPrice == -1.0)
      return false;

   if(isBear == false)
     {
      takeProfit = entryPrice + ((entryPrice / 100) * percent);
     }
   else
     {
      takeProfit = entryPrice - ((entryPrice / 100) * percent);
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::PriceNearExpansion(double expansionLevel,
                                     double tolerancePips = 5.0)
  {
   double expansionPrice = getFibLevel(isBear, OBBody, OBWick, expansionLevel);

   double price = (isBear) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double tol = tolerancePips * _Point;

   return (MathAbs(price - expansionPrice) <= tol);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::PartialClose(double percent)
  {
   if(PartialDone == true)
      return true;

   if(!PositionSelectByTicket(tradeTicket))
      return false;

   double volume      = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = volume * percent;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

// Ajustement au step
   closeVolume = MathFloor(closeVolume / lotStep) * lotStep;

   if(closeVolume < minLot)
      return false;

   return obj_Trade.PositionClosePartial(_Symbol, closeVolume);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void cOrderBlock::ManagePartialTP()
  {
   double rr = GetCurrentRR();

   if(rr < 1.0)
      return;

   if(TPModeInpTP1 == ENUM_TP_FIB && PriceNearExpansion(fibo1rstTP))
     {
      PartialDone = PartialClose(0.5);
     }

   if(PriceNearExpansion(fibo2ndTP))
     {
      PartialDone = PartialClose(0.5);
     }

   if(PriceNearExpansion(fibo3rdTP))
     {
      PartialDone = PartialClose(0.5);
     }
  }

//+------------------------------------------------------------------+
//| OB is valid if next candles close above / below LSSC             |
//+------------------------------------------------------------------+
bool cOrderBlock::checkValidLssc()
  {

   if(lsscValid == false)
     {
      lsscPrice    = open(bar(lssc, CTOB), CTOB);
      double close = close(1, CTOB);

      if(close > lsscPrice && isBear == false)
        {
         addStars();
         lsscValid  = true;
         lsscValidated = time(1,CTOB);
         finalCheck = 3;
        }
      else
        {
         if(close < lsscPrice && isBear == true)
           {
            addStars();
            lsscValid  = true;
            lsscValidated = time(1,CTOB);
            finalCheck = 3;
           }
         else
           {
            return false;
           }
        }
     }
   return lsscValid;
  }

//+------------------------------------------------------------------+
//|                    FVG present sur bougie close qui valide ob    |
//+------------------------------------------------------------------+
bool cOrderBlock::checkValidImbalance()
  {
   if(isImbalanced == true)
      return true;

   int startIndex = bar(startTime);
   int MSSIdx     = bar(MSSEnd);
   imbalancePrice = (isBear == false) ? DBL_MAX : -DBL_MAX;

   if(isBear == false)
     {
      imbalancedDist = MathAbs(low(MSSIdx -1, CTOB) - high(MSSIdx + 1, CTOB)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      imbalancePrice = low(MSSIdx - 1, CTOB);
      FVGStart = time(MSSIdx - 1, CTOB);
      FVGStartLevel = low(MSSIdx - 1, CTOB);
      FVGEnd = time(MSSIdx + 1, CTOB);
      FVGEndLevel = high(MSSIdx+1, CTOB);
     }

   if(isBear == true)
     {
      imbalancedDist = MathAbs(high(MSSIdx - 1, CTOB) - low(MSSIdx + 1, CTOB)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      imbalancePrice = high(MSSIdx -1, CTOB);
      FVGStart = time(MSSIdx -1, CTOB);
      FVGStartLevel = high(MSSIdx -1, CTOB);
      FVGEnd = time(MSSIdx +1, CTOB);
      FVGEndLevel = low(MSSIdx+1, CTOB);
     }

   if(imbalancedDist > 100000000000)
     {
      trashme(ENUM_REASON_IS_LOW_IMBALANCE);
      return false;
     }

   if(imbalancedDist >= minImBalanced)
     {
      isImbalanced = true;
      finalCheck   = 1;
      addStars();
      return true;
     }
   else
     {
      trashme(ENUM_REASON_IS_LOW_IMBALANCE);
      purgedOb = purgedOb + 1;
      return false;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Vérifie sweep de liquidité frais par la jambe MSS                |
//| Retourne false si sweep déjà effectué AVANT le MSS               |
//+------------------------------------------------------------------+
bool cOrderBlock::checkLiquiditySweepBeforeOB(datetime mssLeg, int lookBack = 80)
  {
   if(HasSweepBefore == true || checkedLS == true)
     {
      return true;
     }

// initialise
   sweepLevel = -1.0;
   sweepStart = 0;
   sweepEnd   = 0;

   int mssIndex    = bar(mssLeg);
   int mssStartIdx = bar(MSSStart);

   int    swingIndex        = -1;
   int    effectiveLookBack = MathMax(lookBack, 200);
   double distance          = -1.0;
   double LowLevel          = low(mssIndex);
   double HighLevel         = high(mssIndex);

   if(mssStartIdx <= 0 || mssIndex <= 0)
      return false;

// we look for a swing high low on the higher TF for liquidity
   if(isBear == true)
     {
      // first easy check // add tolerance
      distance = MathAbs(BSL.price - HighLevel) / _Point;
      if((distance <= tolerance && BSL.price >= LowLevel) ||   // 50 pts as tolerance
         BSL.price <= HighLevel)
        {
         sweepLevel = HighLevel;

         // if(hasPreviousTop(mssLeg) > 0)
         //   {return false;}
        }
      if(distance > tolerance)
        {
         return false;
        }
     }
   if(isBear == false)
     {
      distance = MathAbs(SSL.price - LowLevel) / _Point;
      if((distance <= tolerance && SSL.price <= LowLevel) ||   // 50 pts as tolerance
         (SSL.price >= LowLevel))
        {
         sweepLevel = LowLevel;
         // if(hasPreviousBottom(mssLeg) > 0)
         //   {
         //    return false;
         //   }
        }
      if(distance > tolerance)
        {
         return false;
        }
     }

   swingIndex = bar(sweepStart);

   if(sweepLevel < 0)
     {
      checkedLS = true;
      return false;
     }

   if(levelAlreadySweept(sweepStart, isBear, mssLeg) == true)
     {
      checkedLS = true;
      return false;
     }

   sweepEnd       = swingIndex;
   HasSweepBefore = true;
   finalCheck     = 5;
   addStars();

// create object AFTER detection
   string seepName = name + "_sweep1";
   if(ObjectFind(0, seepName) >= 0)
      ObjectDelete(0, seepName);
   ObjectCreate(0, seepName, OBJ_ARROW, 0, sweepStart, sweepLevel);
   ObjectSetInteger(0, seepName, OBJPROP_ARROWCODE, 242);
   ObjectSetInteger(0, seepName, OBJPROP_COLOR, clrYellow);
   checkedLS = true;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::IsFairValueGapFilled()
  {
   if(ImbalancedFilled == true)
      return true;

   int shift = iBarShift(_Symbol, CTOB, startTime);
   if(shift < 2)
      return false;

   if(isBear == false &&
      imbalancePrice >= askPrice &&
      topImpLevel > 0)
     {

      ImbalancedFilled = true;
      finalCheck       = 6;
      reason           = ENUM_REASON_IMBALANCED_FILLED;
      addStars();
      return true;
     }
   if(isBear == true &&
      imbalancePrice <= bidPrice &&
      topImpLevel > 0)
     {
      ImbalancedFilled = true;
      finalCheck       = 6;
      reason           = ENUM_REASON_IMBALANCED_FILLED;
      addStars();
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::checkInZone()
  {
   if(enableDPICT == true && isZoneValid == false)
     {
      PDArray pdAr = checkPDArrayZone(this.index);
      if(isBear == false && pdAr == ENUM_PDARRAY_PREMIUM)
        {
         finalCheck = 7;
         return true;
        }

      if(isBear == true && pdAr == ENUM_PDARRAY_DISCOUNT)
        {
         finalCheck = 7;
         return true;
        }

      if(pdAr == ENUM_PDARRAY_UNDEFINED)
         return true;

      if(pdAr == ENUM_PDARRAY_OVER)
        {
         DrawOB(this.index);
         drawReason(this.index);
         isDone = true;
         stars  = 0;
         return false;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::isAllGood(int i)
  {
   // #26 Daily bias: always re-check even if allChecks=true (bias can flip tick-by-tick)
   if(g_dailyBiasEnabled)
     {
      double dailyOpen = iOpen(_Symbol, PERIOD_D1, 0);
      bool bullishBias = (bidPrice > dailyOpen);
      if(isBear == false && !bullishBias) { reason = ENUM_REASON_IS_COUNTER_BEARISH;  return false; }
      if(isBear == true  &&  bullishBias) { reason = ENUM_REASON_IS_COUNTER_BULLISH;  return false; }
     }

   if(allChecks == true)
      return true;

   if(isImbalanced == false && imbalancePrice == -1.0)
     {
      return false;
     }

   if(isMitigated == true)
     {
      return false;
     }

   if(lssc == 0)
     {
      reason = ENUM_REASON_NO_BOS;
      return false;
     }

   if(isMSS == false && MSSMandatory == true)
     {
      return false;
     }

   if(inpEntryMode == ENUM_EM_AUTO && isLowerMss == false)
     {
      return false;
     }

   if(HasSweepBefore == false)
     {
      reason = ENUM_REASON_NO_LIQUIDITY_SWEPT_BEFORE;
      return false;
     }

   if(ImbalancedFilled == false)
     {
      reason = ENUM_REASON_IMBALANCED_NOT_FILLED;
      return false;
     }

   if(isZoneValid == false && enableDPICT == true)
     {
      return false;
     }

   if(topImpValid == false)
     {
      reason = ENUM_REASON_WEAK_IMPULSE;
      return false;
     }

// OB is almost ready to trade, so if htf trend is ranging and then going opposite
// we cancel the trade
   if(mHTFTrend == TREND_RANGE || mHTFTrend == TREND_UKNOWN)
     {
      if(isRangeTradingOK == false)
        {
         obBuffer[i].reason   = ENUM_REASON_TREND_RANGE_PROTECTION;
         obBuffer[i].wasRange = true;
         return false;
        }
      // Range trading allowed: mark as range direction (lot size will be minimal)
      obBuffer[i].trendDir = TREND_RANGE;
     }

   // Macro trend filter: skip ALL OBs when monthly trend has no clear direction
   if(g_macroTrendEnabled)
     {
      MarketTrend macroTrend = GetMarketTrend(PERIOD_W1, 24);
      if(macroTrend == TREND_RANGE || macroTrend == TREND_UKNOWN)
        {
         reason = ENUM_REASON_MACRO_RANGE;
         return false;
        }
     }

   // D1 trend confluence: reject OB if it trades against the daily trend (W1->D1 cascade)
   if(g_d1TrendEnabled)
     {
      MarketTrend d1Trend = GetMarketTrend(PERIOD_D1, 5);
      if((isBear && d1Trend == TREND_BULLISH) || (!isBear && d1Trend == TREND_BEARISH))
        {
         reason = ENUM_REASON_D1_COUNTER_TREND;
         return false;
        }
     }

  // Swing structure: SELL OB must be near H1 swing high; BUY OB near H1 swing low
   // Uses iHighest/iLowest directly (GetLastSwingHigh breaks on first bar when strictMode=false)
   if(inpRequireSwingStructure)
     {
      double atr14 = getAtr(14, PERIOD_H4);
      double tol   = inpSwingToleranceAtr * atr14;
      if(isBear)
        {
         // Highest H1 high in last 50 bars — OB must be within tolerance of that level
         int    hwIdx  = iHighest(_Symbol, PERIOD_H4, MODE_HIGH, 20, 1);
         double swHigh = (hwIdx >= 0) ? iHigh(_Symbol, PERIOD_H4, hwIdx) : 0;
         if(swHigh > 0 && highPrice < swHigh - tol)
           {
            reason = ENUM_REASON_NO_SWING_STRUCTURE;
            return false;
           }
        }
      else
        {
         // Lowest H1 low in last 50 bars — OB must be within tolerance of that level
         int    lwIdx = iLowest(_Symbol, PERIOD_H4, MODE_LOW, 20, 1);
         double swLow = (lwIdx >= 0) ? iLow(_Symbol, PERIOD_H4, lwIdx) : 0;
         if(swLow > 0 && lowPrice > swLow + tol)
           {
            reason = ENUM_REASON_NO_SWING_STRUCTURE;
            return false;
           }
        }
     }

  // H4 trend confluence: reject OB if it trades against the H4 trend
   if(g_h4TrendEnabled)
     {
      MarketTrend h4Trend = GetMarketTrend(PERIOD_H4, 5);
      if((isBear && h4Trend == TREND_BULLISH) || (!isBear && h4Trend == TREND_BEARISH))
        {
         reason = ENUM_REASON_H4_COUNTER_TREND;
         return false;
        }
     }

   // #21 Spread cap: skip entry if spread is too wide
   if(inpMaxSpread > 0 && spread > inpMaxSpread)
     {
      reason = ENUM_REASON_SPREAD_TOO_WIDE;
      return false;
     }

   // #23 Max simultaneous positions per direction
   if(inpMaxPositionsPerDir > 0)
     {
      int sameDir = 0;
      for(int j = 0; j < ArraySize(obBuffer); j++)
         if(j != i && obBuffer[j].tradeTicket != INVALID_TICKET && obBuffer[j].isBear == isBear)
            sameDir++;
      if(sameDir >= inpMaxPositionsPerDir)
        {
         reason = ENUM_REASON_TRADE_ONGOING;
         return false;
        }
     }

   allChecks  = true;
   finalCheck = 11;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::isMinQuality()
  {
   // Minimum quality gate: MSS + FVG + impulse + daily bias — no sweep required, no FVG-fill required
   if(isMitigated)                                       return false;
   if(lssc == 0)                                         return false;
   if(isMSS == false)                                    return false;
   if(isImbalanced == false || imbalancePrice < 0.0)     return false;
   if(topImpValid == false)                              return false;

   // Daily bias — fast reversal guard (always re-check)
   if(g_dailyBiasEnabled)
     {
      double dailyOpen = iOpen(_Symbol, PERIOD_D1, 0);
      bool bullishBias = (bidPrice > dailyOpen);
      if(isBear == false && !bullishBias) return false;
      if(isBear == true  &&  bullishBias) return false;
     }

   return true;
  }

void cOrderBlock::trashme(NoTradeReason r)
  {
   isDone  = true;
   stars   = 0;
   OBcolor = clrGray;
   reason  = r;
  }


//+------------------------------------------------------------------+
//| CheckOBBreakerBlock - Detects when OB becomes a BreakerBlock   |
//| Called when isMitigated = true and we wait for price to break  |
//| through the OB zone. If price breaks, we flip isBear and mark  |
//| it as a BreakerBlock.                                          |
//+------------------------------------------------------------------+
bool cOrderBlock::CheckOBBreakerBlock()
  {
   if(inpEnableBreakerBlock == false)
      return false;

   if(isMitigated == false)
      return false;

   if(isBreakerBlock == true)
      return true;

    // Bullish OB (original buy zone): check if price breaks below mitigatedLine
    if(isBear == false)
      {
       if(bidPrice < mitigatedLine)
         {
          isBreakerBlock = true;
          breakerBlockTime = TimeCurrent();
          breakerBlockPrice = mitigatedLine;
          isBear = true;  // Flip direction - now trading bearish
          OBcolor = clrOrange;  // Visual indication
          reason = ENUM_REASON_BREAKERBLOCK;
          Print("DEBUG CheckOBBreakerBlock: Bullish OB became BreakerBlock! isBear flipped to ", isBear);
          return true;
         }
      }

    // Bearish OB (original sell zone): check if price breaks above mitigatedLine
    if(isBear == true)
      {
       if(askPrice > mitigatedLine)
        {
         isBreakerBlock = true;
         breakerBlockTime = TimeCurrent();
          breakerBlockPrice = mitigatedLine;
         isBear = false;  // Flip direction - now trading bullish
         OBcolor = clrOrange;  // Visual indication
         reason = ENUM_REASON_BREAKERBLOCK;
         Print("DEBUG CheckOBBreakerBlock: Bearish OB became BreakerBlock! isBear flipped to ", isBear);
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool cOrderBlock::IsIndexValid(int i, orderBlock &array[])
  {
   return i >= 0 && i < ArraySize(array);
  }
//+------------------------------------------------------------------+