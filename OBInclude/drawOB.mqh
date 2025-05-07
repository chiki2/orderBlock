//+------------------------------------------------------------------+
//|                                                       drawOB.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void drawBreakLevel(string objName,datetime time1,double price1,
                    datetime time2,double price2,color clr,int direction)
  {
   if(ObjectFind(0,objName) < 0)
     {
      ObjectCreate(0,objName,OBJ_ARROWED_LINE,0,time1,price1,time2,price2);
      ObjectSetInteger(0,objName,OBJPROP_TIME,0,time1);
      ObjectSetDouble(0,objName,OBJPROP_PRICE,0,price1);
      ObjectSetInteger(0,objName,OBJPROP_TIME,1,time2);
      ObjectSetDouble(0,objName,OBJPROP_PRICE,1,price2);
      ObjectSetInteger(0,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,objName,OBJPROP_WIDTH,2);

      string txt = " Break   ";
      string objNameDescr = objName + txt;
      ObjectCreate(0,objNameDescr,OBJ_TEXT,0,time2,price2);
      ObjectSetInteger(0,objNameDescr,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,objNameDescr,OBJPROP_FONTSIZE,10);
      if(direction > 0)
        {
         ObjectSetInteger(0,objNameDescr,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
         ObjectSetString(0,objNameDescr,OBJPROP_TEXT, " " + txt);
        }
      if(direction < 0)
        {
         ObjectSetInteger(0,objNameDescr,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);
         ObjectSetString(0,objNameDescr,OBJPROP_TEXT, " " + txt);
        }
     }
   ChartRedraw(0);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void  DrawOB(int obIndex = 0, int start = 0)
  {
   datetime cutoff = TimeCurrent() - outdatedOB * 3600;
   if(obBuffer[obIndex ].startTime <= cutoff && obBuffer[obIndex].isDone == false)
     {
      obBuffer[obIndex].stars = 0;
     }
   if(obBuffer[obIndex].stars > 1 || showOB == true)
     {

      int i = obBuffer[obIndex].index;

      //create the new rectangle using candle3s low, starting at candle 2, using candle 1s high and ending at candle 0
      ObjectCreate(0,obBuffer[obIndex].name,OBJ_RECTANGLE,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].highPrice,
                   (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                   obBuffer[obIndex].lowPrice);

      // prev high & prev low
      if(obBuffer[obIndex].prevlowi != 0)
        {
         int barIndex = iBarShift(_Symbol, HTOB, obBuffer[obIndex].prevlowi, true);
         ObjectCreate(0,obBuffer[obIndex].name + "-prevlow", OBJ_ARROW,0, obBuffer[obIndex].prevlowi, high(barIndex));
         ObjectSetInteger(0,obBuffer[obIndex].name + "-prevlow",OBJPROP_ARROWCODE,234);
         ObjectSetInteger(0,obBuffer[obIndex].name + "-prevlow",OBJPROP_COLOR,clrBlue);
         ObjectSetString(ChartID(),obBuffer[obIndex].name + "-prevlow",OBJPROP_FONT,"Wingdings");
         ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-prevlow",OBJPROP_FONTSIZE,30);
        }
      if(obBuffer[obIndex].prevhighi != 0)
        {
         int barIndex = iBarShift(_Symbol, HTOB, obBuffer[obIndex].prevhighi, true);
         ObjectCreate(0,obBuffer[obIndex].name + "-prevhigh", OBJ_ARROW,0, obBuffer[obIndex].prevhighi, low(barIndex));
         ObjectSetInteger(0,obBuffer[obIndex].name + "-prevhigh",OBJPROP_ARROWCODE,233);
         ObjectSetInteger(0,obBuffer[obIndex].name + "-prevhigh",OBJPROP_COLOR,clrRed);
         ObjectSetString(ChartID(),obBuffer[obIndex].name + "-prevhigh",OBJPROP_FONT,"Wingdings");
         ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-prevhigh",OBJPROP_FONTSIZE,30);
        }

      ObjectCreate(0,obBuffer[obIndex].name + "-mitiline",OBJ_TREND,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].mitigatedLine,
                   (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                   obBuffer[obIndex].mitigatedLine);

      //draw liquidity line
      if(obBuffer[obIndex].lowLiquid != 0.0)
        {
         // create imbalanced line
         ObjectCreate(0,obBuffer[obIndex].name + "-lqLine",OBJ_TREND,0,
                      obBuffer[obIndex].startTime,
                      obBuffer[obIndex].lowLiquid,
                      (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                      obBuffer[obIndex].lowLiquid);
        }

      ObjectCreate(0,obBuffer[obIndex].name + "-50",OBJ_TREND,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].fib50,
                   rA[3].time,
                   obBuffer[obIndex].fib50);

      if(obBuffer[obIndex].isImbalanced == true)
        {
         // create imbalanced line
         ObjectCreate(0,obBuffer[obIndex].name + "-ImLine",OBJ_TREND,0,
                      obBuffer[obIndex].startTime,
                      obBuffer[obIndex].imbalancePrice,
                      (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                      obBuffer[obIndex].imbalancePrice);
         ObjectCreate(0,obBuffer[obIndex].name + "-ImVal", OBJ_TEXT, 0,
                      (obBuffer[obIndex].startTime + rA[3].time) / 2,
                      (obBuffer[obIndex].imbalancePrice + obBuffer[obIndex].highPrice) / 2);
        }
      ObjectCreate(0,obBuffer[obIndex].name + "-text", OBJ_TEXT, 0,
                   (obBuffer[obIndex].startTime + rA[3].time) / 2,
                   (obBuffer[obIndex].highPrice + obBuffer[obIndex].lowPrice) / 2);
      // Fibo 127
      ObjectCreate(0,obBuffer[obIndex].name + "-fib127",OBJ_TREND,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].fib127,
                   (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                   obBuffer[obIndex].fib127);

      // Fibo 161
      ObjectCreate(0,obBuffer[obIndex].name + "-fib161",OBJ_TREND,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].fib1618,
                   (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                   obBuffer[obIndex].fib1618);

      // Fibo 232
      ObjectCreate(0,obBuffer[obIndex].name + "-fib232",OBJ_TREND,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].fib23812,
                   (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                   obBuffer[obIndex].fib23812);


      // Fibo SL
      ObjectCreate(0,obBuffer[obIndex].name + "-sl",OBJ_TREND,0,
                   obBuffer[obIndex].startTime,
                   obBuffer[obIndex].stopLoss,
                   (obBuffer[obIndex].isMitigated == false) ? rA[3].time : obBuffer[obIndex].mitigatedTime,
                   obBuffer[obIndex].stopLoss);
      ObjectSetString(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_TEXT,getStars(obIndex));
      ObjectSetString(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_FONT,"Wingdings");
      ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_FONTSIZE,20);
      ObjectSetInteger(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_COLOR,obBuffer[obIndex].OBcolor);
      ObjectSetInteger(0,obBuffer[obIndex].name,OBJPROP_FILL, false);
      ObjectSetString(ChartID(),obBuffer[obIndex].name + "-text",OBJPROP_TOOLTIP,
                      "obhigh : " + DoubleToString(obBuffer[obIndex].highPrice, 2) + "\n" +
                      "oblow : " + DoubleToString(obBuffer[obIndex].lowPrice, 2) + "\n"   +
                      "Cross BOS : " + (obBuffer[obIndex].isBOS ? "True" : "False" )+ "\n"   +
                      "Is done : " + (obBuffer[obIndex].isDone ? "True" : "False" )+ "\n"   +
                      "Did cross 50 : " + (obBuffer[obIndex].cross50 ? "True" : "False" ) + "\n");


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
      ObjectSetInteger(0,obBuffer[obIndex].name + "-50",OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-50",OBJPROP_COLOR, obBuffer[obIndex].isMitigated == false ? clrCyan : obBuffer[obIndex].OBcolor);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-fib127",OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-fib127",OBJPROP_COLOR, obBuffer[obIndex].isMitigated == false ? clrCyan : obBuffer[obIndex].OBcolor);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-fib161",OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-fib161",OBJPROP_COLOR, obBuffer[obIndex].isMitigated == false ? clrBlueViolet : obBuffer[obIndex].OBcolor);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-fib232",OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-fib232",OBJPROP_COLOR, obBuffer[obIndex].isMitigated == false ? clrGold : obBuffer[obIndex].OBcolor);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-mitiline",OBJPROP_COLOR, obBuffer[obIndex].OBcolor);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-mitiline",OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-sl",OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0,obBuffer[obIndex].name + "-sl",OBJPROP_STYLE, STYLE_DASHDOTDOT);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawPWDHL()
  {
   pwl = iLow(_Symbol,PERIOD_W1,1);
   pwh = iHigh(_Symbol,PERIOD_W1,1);
   if(ObjectFind(0,"ob-pwl")<0)
     {
      ObjectCreate(0,"ob-pwl",OBJ_TREND,0,
                   iTime(_Symbol,PERIOD_W1,1),
                   pwl,
                   rA[3].time,
                   pwl);
     }
   if(ObjectFind(0,"ob-pwl-lbl")<0)
     {
      ObjectCreate(0,"ob-pwl-lbl", OBJ_TEXT, 0,
                   rA[3].time,
                   pwl);
     }
   if(ObjectFind(0,"ob-pwh")<0)
     {
      ObjectCreate(0,"ob-pwh",OBJ_TREND,0,
                   iTime(_Symbol,PERIOD_W1,1),
                   pwh,
                   rA[3].time,
                   pwh);
     }
   if(ObjectFind(0,"ob-pwh-lbl")<0)
     {
      ObjectCreate(0,"ob-pwh-lbl", OBJ_TEXT, 0,
                   rA[3].time,
                   pwh);
     }

   ObjectSetInteger(0,"ob-pwl",OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0,"ob-pwl",OBJPROP_COLOR, clrYellowGreen);
   ObjectSetInteger(0,"ob-pwl", OBJPROP_TIME, 1, rA[3].time);
   ObjectSetString(0,"ob-pwl-lbl",OBJPROP_TEXT,"PWL :" + DoubleToString(pwl, 4));
   ObjectSetInteger(0,"ob-pwl-lbl", OBJPROP_TIME, 1, rA[3].time);
   ObjectSetInteger(0,"ob-pwh",OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0,"ob-pwh",OBJPROP_COLOR, clrYellowGreen);
   ObjectSetInteger(0,"ob-pwh", OBJPROP_TIME, 1, rA[3].time);
   ObjectSetString(0,"ob-pwh-lbl",OBJPROP_TEXT,"PWH :" + DoubleToString(pwh, 4));
   ObjectSetInteger(0,"ob-pwh-lbl", OBJPROP_TIME, 1, rA[3].time);

   pdl = iLow(_Symbol,PERIOD_D1,1);
   pdh = iHigh(_Symbol,PERIOD_D1,1);

   if(ObjectFind(0,"ob-pdl")<0)
     {
      ObjectCreate(0,"ob-pdl",OBJ_TREND,0,
                   iTime(_Symbol,PERIOD_W1,1),
                   pdl,
                   rA[3].time,
                   pdl);
      ObjectCreate(0,"ob-pdl-lbl", OBJ_TEXT, 0,
                   rA[3].time,
                   pdl);
     }
   if(ObjectFind(0,"ob-pdh")<0)
     {
      ObjectCreate(0,"ob-pdh",OBJ_TREND,0,
                   iTime(_Symbol,PERIOD_D1,1),
                   pdh,
                   rA[3].time,
                   pdh);
      ObjectCreate(0,"ob-pdh-lbl", OBJ_TEXT, 0,
                   rA[3].time,
                   pdh);
     }


   ObjectSetInteger(0,"ob-pdl",OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0,"ob-pdl",OBJPROP_COLOR, clrYellowGreen);
   ObjectSetString(0,"ob-pdl-lbl",OBJPROP_TEXT,"PDL :" + DoubleToString(pdl,4));
   ObjectSetInteger(0,"ob-pdh",OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0,"ob-pdh",OBJPROP_COLOR, clrYellowGreen);
   ObjectSetString(0,"ob-pdh-lbl",OBJPROP_TEXT,"PDH :" + DoubleToString(pdh,4));
  }


// Functions for BOS MSS
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void drawSwingPoint(string objName,datetime time,double price,int arrCode,
                    color clr,int direction)
  {

   if(ObjectFind(0,objName) < 0)
     {
      ObjectCreate(0,objName,OBJ_ARROW,0,time,price);
      ObjectSetInteger(0,objName,OBJPROP_ARROWCODE,arrCode);
      ObjectSetInteger(0,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,objName,OBJPROP_FONTSIZE,10);
      if(direction > 0)
         ObjectSetInteger(0,objName,OBJPROP_ANCHOR,ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0,objName,OBJPROP_ANCHOR,ANCHOR_BOTTOM);

      string txt = " BoS";
      string objNameDescr = objName + txt;
      ObjectCreate(0,objNameDescr,OBJ_TEXT,0,time,price);
      ObjectSetInteger(0,objNameDescr,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,objNameDescr,OBJPROP_FONTSIZE,10);
      if(direction > 0)
        {
         ObjectSetInteger(0,objNameDescr,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetString(0,objNameDescr,OBJPROP_TEXT, " " + txt);
        }
      if(direction < 0)
        {
         ObjectSetInteger(0,objNameDescr,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
         ObjectSetString(0,objNameDescr,OBJPROP_TEXT, " " + txt);
        }
     }
   ChartRedraw(0);
  }
