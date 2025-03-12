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
input ENUM_TIMEFRAMES HTOB = PERIOD_M15;
input ENUM_TIMEFRAMES LTOB = PERIOD_M5;

//

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
   double            highLiquid;
   double            lowLiquid;
   short             trendDir;
   bool              isLT;
   int               parent;

   void              init(string myName,int myIndex, datetime startT,
                          double highP,double lowP, bool bear = false,
                          long oC = clrBlue, bool LT = false)
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
      isLT = LT;
      trendDir = trendDirection;
     }
  };

MqlRates rA[3];
MqlRates innerRA[3];
orderBlock obBuffer[];
short trendDirection;
string trendD;
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
   CopyRates(_Symbol,HTOB,0,lookBackPeriod,initRa);
   for(int a = 0; a < lookBackPeriod; a++)
     {
      ArrayCopy(rA, initRa, 0, a, 3);
      detectNewOB();
      detectTrend(a);
      //redraw OBs
      for(int i = 0 ; i < ArraySize(obBuffer); i++)
        {
         obBuffer[i].isMitigated = checkMitigated(i, (obBuffer[i].isBear == true) ? rA[2].high : rA[2].low);
         detectInnerOB(i);
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
      ObjectsDeleteAll(0,obBuffer[i].name + "-lqLine");
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

   detectTrend(0);
   Comment("OB Detector ...." +
            "\nHigh timeframe : " + EnumToString(HTOB) +
            "\nTotal OB count : " + IntegerToString(ArraySize(obBuffer)) + 
            "\nTrendDirection : " + trendD);
// detect OB
   CopyRates(_Symbol, HTOB, 0, 3, rA);
   if(alreadyFound() == false)
     {
      detectNewOB();
     }

//redraw OBs
   for(int i = 0 ; i < ArraySize(obBuffer); i++)
     {
      obBuffer[i].isMitigated = checkMitigated(i);
      //detectLiquidity(i);
      DrawOB(i);
      detectInnerOB(i);
     }
   cleanOBBuffer();
  }
//+------------------------------------------------------------------+
void detectInnerOB(int a = 0){
   CopyRates(_Symbol, LTOB, 0, 3, rA);
   detectNewOB(true, a);

}


void detectTrend(int a = 0){
      double firstClose, lastClose;
      firstClose  = iClose(Symbol(), HTOB, a+5);
      lastClose   = iClose(Symbol(), HTOB, a);
      
      double momentum = (lastClose / firstClose) * 100;
      // Determine Trend
      if (momentum > 100 ) {
         trendD = "Uptrend Detected";
         trendDirection = 1;
      } else if (momentum < 100) {
         trendD = "Downtrend Detected";
         trendDirection = -1;
      } else {
         trendD = "Sideways Market";
         trendDirection = 0;
      }
}

void detectNewOB(bool innerMode = false, int a = 0 )
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
      else{
         obBuffer[obs].stars = obBuffer[obs].stars-1;
      }
      if(obBuffer[obs].trendDir == 1){
         obBuffer[obs].stars = obBuffer[obs].stars+1;
      }
      // we are in a lower timeframe OB
      if ( innerMode == true && obBuffer[a].parent == 0 ){
         Print("inner up");
         obBuffer[a].stars = 5;
         obBuffer[a].parent = obs;
         obBuffer[obs].isLT = true;
         obBuffer[obs].parent = a;
         obBuffer[obs].OBcolor = clrAzure;
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
      double imBalancedDiff = MathAbs((rA[2].high - rA[0].low) / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
      if(imBalancedDiff >= minImBalanced)
        {
         obBuffer[obs].isImbalanced = true;
         obBuffer[obs].stars = obBuffer[obs].stars+1;
         obBuffer[obs].imbalancePrice = rA[2].high;
         obBuffer[obs].imbalancedDist = imBalancedDiff;
        }
      else{
         obBuffer[obs].stars = obBuffer[obs].stars-1;
      }
      if(obBuffer[obs].trendDir == -1){
         obBuffer[obs].stars = obBuffer[obs].stars+1;
      }
      if ( innerMode == true && obBuffer[a].parent == 0 ){
         Print("inner down");
         obBuffer[a].stars = 5;
         obBuffer[a].parent= obs;
         obBuffer[obs].isLT = true;
         obBuffer[obs].parent = a;
         obBuffer[obs].OBcolor = clrRosyBrown;
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
double lowAvg(double tolerance = 2.0){
}

void detectLiquidity(int i, double tolerance = 2.0)
  {
   double lowArray[];
   double highArray[];
   double lowestAvg = 0.0;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(obBuffer[i].isBear == false &&
      currentPrice >= obBuffer[i].imbalancePrice)
     {
      CopyLow(_Symbol, HTOB, iTime(_Symbol,HTOB,0), obBuffer[i].startTime, lowArray);
      CopyHigh(_Symbol, HTOB, iTime(_Symbol,HTOB,0), obBuffer[i].startTime, highArray);

      // we find the highestpoint after the OB
      for(int a = 0; a < ArraySize(highArray);a++)
        {
         if(obBuffer[i].highLiquid <=  highArray[a])
           {
            obBuffer[i].highLiquid = highArray[a];
           }
        }

      for(int a = 0; a < ArraySize(lowArray);a++)
        {
         lowestAvg = lowestAvg + lowArray[a];
        }

      obBuffer[i].lowLiquid = lowestAvg / ArraySize(lowArray);
     }

   if(obBuffer[i].isBear == true &&
      currentPrice <= obBuffer[i].imbalancePrice)
     {
      CopyLow(_Symbol, HTOB, iTime(_Symbol,HTOB,0), obBuffer[i].startTime, lowArray);
      CopyHigh(_Symbol, HTOB, iTime(_Symbol,HTOB,0), obBuffer[i].startTime, highArray);

      // BEARISH we find the lowest point after the OB
      for(int a = 0; a < ArraySize(lowArray);a++)
        {
         if(obBuffer[i].lowLiquid >=  lowArray[a])
           {
            obBuffer[i].lowLiquid = lowArray[a];
           }
        }

      // caution we take opposite
      for(int a = 0; a < ArraySize(highArray);a++)
        {
         lowestAvg = lowestAvg + highArray[a];
        }

      obBuffer[i].lowLiquid = lowestAvg / ArraySize(highArray);

     }

   // if we have liquidity then we grant ob with another star
   if(obBuffer[i].lowLiquid != 0.0)
     {
      obBuffer[i].stars = obBuffer[i].stars + 1;
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void cleanOBBuffer()
  {
   for(int a = 0; a < ArraySize(obBuffer); a++)
     {
      if(obBuffer[a].stars <= 1)
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
   double currentPrice = (lastPrice != 0.0) ? lastPrice : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(obBuffer[i].isMitigated == true)
      return true;
   if(obBuffer[i].isBear == false &&
      currentPrice <= obBuffer[i].highPrice)
     {
      obBuffer[i].OBcolor = clrYellow;
      obBuffer[i].stars   = 1;
      return true;
     }

   if(obBuffer[i].isBear == true &&
      currentPrice >= obBuffer[i].lowPrice)
     {
      obBuffer[i].OBcolor = clrYellow;
      obBuffer[i].stars   = 1;
      return true;
     }

   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawOB(int obIndex = 0, int start = 0)
  {
   ObjectDelete(0, obBuffer[obIndex].name + "-lqLine");
   ObjectDelete(0, obBuffer[obIndex].name + "-ImLine");
   ObjectDelete(0, obBuffer[obIndex].name + "-ImVal");
   ObjectDelete(0, obBuffer[obIndex].name);
   ObjectDelete(0, obBuffer[obIndex].name + "-text");

   if(obBuffer[obIndex].stars > 1)
     {

      int i = obBuffer[obIndex].index;

      //create the new rectangle using candle3s low, starting at candle 2, using candle 1s high and ending at candle 0
      ObjectCreate(0,obBuffer[obIndex].name,OBJ_RECTANGLE,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].highPrice,
                   rA[2].time,
                   obBuffer[obIndex].lowPrice);

      //draw liquidity line
      if(obBuffer[obIndex].lowLiquid != 0.0)
        {
         // create imbalanced line
         ObjectCreate(0,obBuffer[obIndex].name + "-lqLine",OBJ_TREND,0,
                      obBuffer[obIndex].startTime,
                      obBuffer[obIndex].lowLiquid ,
                      rA[2].time,
                      obBuffer[obIndex].lowLiquid );
        }

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
      ObjectCreate(0,obBuffer[obIndex].name + "-text", OBJ_TEXT, 0,
                (obBuffer[obIndex].startTime + rA[2].time) / 2,
                (obBuffer[obIndex].highPrice + obBuffer[obIndex].lowPrice) / 2);

     }

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
   ObjectSetInteger(0,obBuffer[obIndex].name + "-lqLine",OBJPROP_COLOR, obBuffer[obIndex].OBcolor);
   ObjectSetInteger(0,obBuffer[obIndex].name + "-lqLine",OBJPROP_STYLE, STYLE_DASH);

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
