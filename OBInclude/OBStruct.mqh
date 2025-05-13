//+------------------------------------------------------------------+
//|                                                     OBStruct.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
struct orderBlock
  {

   string            name;
   int               index;
   datetime          startTime;
   double            entryPrice;
   double            highPrice;
   double            lowPrice;
   double            imbalancePrice;
   bool              isMitigated;
   bool              isBOS;
   bool              DoTrailing;
   bool              DoRevengeTrailing;
   bool              sweepRevenge;
   datetime          mitigatedTime;
   double            mitigatedLine;
   bool              isImbalanced;
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
   double            fib127, fib1618, fib200, fib23812; // to validate rehearsal as enough
   datetime          prevlowi, prevhighi;
   bool              cross127, cross161,cross238,cross50;
   short             trendDir;
   int               parent;
   ulong             tradeTicket;
   ulong             revengeTicket;
   ulong             lightBuzzTicket;
   bool              dolightbuzzTrailing;
   bool              isLightbuzz;
   bool              isrevenge;
   double            takeProfit;
   double            stopLoss;

  
   void              init(string myName,int myIndex, datetime startT,
                          double highP,double lowP, double OBBdy, double lastCandlesWick, bool bear = false,
                          long oC = clrBlue)
     {

      name = myName;
      startTime = startT;
      index= myIndex;
      highPrice = highP;
      lowPrice  = lowP;
      stars= 1; // because has minimal body
      isBear = bear;
      revengeTicket = 0;
      lightBuzzTicket = 0;
      sweepRevenge= false;
      isMitigated = false;
      isImbalanced= false;
      isLightbuzz = false;
      isDone=false;
      isBOS= false;
      DoTrailing = false;
      OBcolor = oC;
      trendDir = trendDirection;
      stars = (trendDirection == 1 && isBear == false) ? stars + 1 : 0;
      stars = (trendDirection == -1 && isBear == true) ? stars + 1 : 0;
      OBBody = OBBdy;
      OBWick = lastCandlesWick;

      getFibLevels(myIndex);

      cross127    = false;
      cross161    = false;
      cross238    = false;
      cross50     = false;

      mitigatedLine = (highPrice + lowPrice) / 2;
      if(isFirstOB(myIndex) == false)
        {
         OBcolor = clrPurple;
         isDone = true;
         stars = 0;
        }

     };

  };