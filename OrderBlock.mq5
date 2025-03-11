//+------------------------------------------------------------------+
//|                                                EA OrderBlock.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.03"

input int lookBackPeriod   = 500;
input int minBodySize      = 20;
input int minImBalanced    = 20;

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
   bool              isImbalanced;
   double            imbalancedDist;
   bool              isBear;
   int               stars;
   long              OBcolor;
   bool              isDone;

   void              init(string myName,int myIndex, datetime startT, double highP,double lowP, bool bear = false, long oC = clrBlue)
     {

      name = myName;
      startTime = startT;
      index= myIndex;
      highPrice = highP;
      lowPrice  = lowP;
      stars= 1;
      isBear = bear;
      isMitigated = false;
      isImbalanced= false;
      isDone=false;
      OBcolor = oC;
     }
  };

MqlRates rA[3];
orderBlock obBuffer[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Comment("initializing...");
// retrieve previous OB
   MqlRates initRa[];
   ArrayResize(initRa, lookBackPeriod);
   CopyRates(_Symbol,PERIOD_CURRENT,0,lookBackPeriod,initRa);
   for(int a = 0; a < lookBackPeriod; a++)
     {
      ArrayCopy(rA, initRa, 0, a, 3);
      detectNewOB();
      //redraw OBs
      for(int i = 0 ; i < ArraySize(obBuffer); i++)
        {
         obBuffer[i].isMitigated = checkMitigated(i, (obBuffer[i].isBear == true) ? rA[2].high : rA[2].low );
         DrawOB(i);
        }
      cleanOBBuffer();
     }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   for(int i = 0; i < ArraySize(obBuffer); i++)
     {
      ObjectsDeleteAll(0,obBuffer[i].name);
      ObjectsDeleteAll(0,obBuffer[i].name + "-ImLine");
      ObjectsDeleteAll(0,obBuffer[i].name + "-ImVal");
      ObjectsDeleteAll(0,obBuffer[i].name + "-text");

     }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(timeToTrade() == false)
     {
      Comment("Not the right time yet");
      //return;
     }


   Comment("Awaiting new Order Block....\n" +
           "Total OB count : " + IntegerToString(ArraySize(obBuffer)));
// detect OB
   CopyRates(_Symbol, Period(), 0, 3, rA);
   if(alreadyFound() == false)
     {
      detectNewOB();
     }

//redraw OBs
   for(int i = 0 ; i < ArraySize(obBuffer); i++)
     {
      obBuffer[i].isMitigated = checkMitigated(i);
      DrawOB(i);
     }
   cleanOBBuffer();
  }
//+------------------------------------------------------------------+
void detectNewOB()
  {
   if(rA[0].close < rA[0].open &&   // last candle bearish
      rA[1].close > rA[1].open && // first candle bullish
      rA[2].close> rA[2].open && // second candle bullish
      rA[2].low > rA[0].high && // check if 2d high is higher than low candle bearish
      rA[1].high - rA[1].low >= minBodySize * Point())
     {
      int obs = ArraySize(obBuffer);
      ArrayResize(obBuffer,obs+1);

      //create the new rectangle using candle3s low, starting at candle 2, using candle 1s high and ending at candle 0
      obBuffer[obs].init("Rectangle-" + (string)obs,obs,rA[0].time, rA[0].high, rA[0].low, false);
      double imBalancedDiff = (rA[2].low - rA[0].high) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(imBalancedDiff >= minImBalanced)
        {
         obBuffer[obs].isImbalanced = true;
         obBuffer[obs].stars = obBuffer[obs].stars+1;
         obBuffer[obs].imbalancePrice = rA[2].low;
         obBuffer[obs].imbalancedDist = imBalancedDiff;
        }
      DrawOB(obs);
     }

//  bearish OB
   if(rA[0].close > rA[0].open &&   // last candle bullish
      rA[1].close < rA[1].open && // first candle bearish
      rA[2].close < rA[2].open && // second candle bearish
      rA[2].high < rA[0].low && // check if high is higher than low candle bearish
      rA[1].high - rA[1].low >= minBodySize * Point())
     {
      int obs = ArraySize(obBuffer);
      ArrayResize(obBuffer,obs+1);

      obBuffer[obs].init("Rectangle-" + (string)obs,obs,rA[0].time, rA[0].high, rA[0].low, true,clrRed);
      double imBalancedDiff = (rA[2].high - rA[0].low) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(imBalancedDiff >= minImBalanced)
        {
         obBuffer[obs].isImbalanced = true;
         obBuffer[obs].stars = obBuffer[obs].stars+1;
         obBuffer[obs].imbalancePrice = rA[2].high;
         obBuffer[obs].imbalancedDist = imBalancedDiff;
        }
      DrawOB(obs);
     }

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool alreadyFound()
  {
   for(int a = 0; a < ArraySize(obBuffer); a++)
     {
      if(obBuffer[a].startTime == rA[0].time)
        {
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void cleanOBBuffer()
  {
   for(int a = 0; a < ArraySize(obBuffer); a++)
     {
      if(obBuffer[a].stars == 0)
        {
         ArrayRemove(obBuffer,a, 1);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool checkMitigated(int i, double lastPrice = 0.0)
  {
   double currentPrice = ( lastPrice != 0.0 ) ? lastPrice : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(obBuffer[i].isMitigated == true)
      return true;
   if(obBuffer[i].isBear == false &&
      currentPrice <= obBuffer[i].highPrice)
     {
      obBuffer[i].OBcolor = clrYellow;
      obBuffer[i].stars   = 0;
      return true;
     }

   if(obBuffer[i].isBear == true &&
      currentPrice >= obBuffer[i].lowPrice)
     {
      obBuffer[i].OBcolor = clrYellow;
      obBuffer[i].stars   = 0;
      return true;
     }

   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawOB(int obIndex = 0, int start = 0)
  {
   ObjectDelete(0, obBuffer[obIndex].name + "-ImLine");
   ObjectDelete(0, obBuffer[obIndex].name + "-ImVal");
   ObjectDelete(0, obBuffer[obIndex].name);
   ObjectDelete(0, obBuffer[obIndex].name + "-text");

   if(obBuffer[obIndex].stars >= 1)
     {

      int i = obBuffer[obIndex].index;

      //create the new rectangle using candle3s low, starting at candle 2, using candle 1s high and ending at candle 0
      ObjectCreate(0,obBuffer[obIndex].name,OBJ_RECTANGLE,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].highPrice,
                   rA[2].time,
                   obBuffer[obIndex].lowPrice);

      if(obBuffer[obIndex].isImbalanced == true)
        {
         // create imbalanced line
         ObjectCreate(0,obBuffer[obIndex].name + "-ImLine",OBJ_TREND,0,
                      obBuffer[obIndex].startTime,
                      obBuffer[obIndex].imbalancePrice,
                      rA[2].time,
                      obBuffer[obIndex].imbalancePrice);
         ObjectCreate(0,obBuffer[obIndex].name + "-ImVal", OBJ_TEXT, 0,
                      obBuffer[obIndex].startTime,
                      (obBuffer[obIndex].imbalancePrice + obBuffer[obIndex].highPrice) / 2);
        }
     }
   ObjectCreate(0,obBuffer[obIndex].name + "-text", OBJ_TEXT, 0,
                (obBuffer[obIndex].startTime + rA[2].time) / 2,
                (obBuffer[obIndex].highPrice + obBuffer[obIndex].lowPrice) / 2 );
   ObjectSetString(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_TEXT,"  " +IntegerToString(obBuffer[obIndex].stars) + " Stars");
   ObjectSetString(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_FONT,"Arial");
   ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_FONTSIZE,15);
   ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_COLOR,obBuffer[obIndex].OBcolor);
   ObjectSetInteger(0,obBuffer[obIndex].name,OBJPROP_COLOR,obBuffer[obIndex].OBcolor);
   ObjectSetInteger(0,obBuffer[obIndex].name + "-ImLine",OBJPROP_COLOR, obBuffer[obIndex].OBcolor);
   ObjectSetString(ChartID(),obBuffer[obIndex].name + "-ImVal",OBJPROP_TEXT,"  " +DoubleToString(obBuffer[obIndex].imbalancedDist,2));
   ObjectSetString(ChartID(),obBuffer[obIndex].name + "-ImVal",OBJPROP_FONT,"Arial");
   ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-ImVal",OBJPROP_FONTSIZE,15);
   ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-ImVal",OBJPROP_COLOR,obBuffer[obIndex].OBcolor);
   ObjectSetInteger(0,obBuffer[obIndex].name,OBJPROP_COLOR,obBuffer[obIndex].OBcolor);
   ObjectSetInteger(0,obBuffer[obIndex].name + "-ImVal",OBJPROP_COLOR, obBuffer[obIndex].OBcolor);

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool timeToTrade()
  {
   MqlDateTime mdt;
   TimeCurrent(mdt);

   if(mdt.hour > 14 && mdt.hour < 18)
     {
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
