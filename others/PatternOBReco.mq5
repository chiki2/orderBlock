//+------------------------------------------------------------------+
//|                                                PatternOBReco.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property tester_file "pattern.csv"

#include <Math/Stat/Stat.mqh>

double pattern[];
int   patternBars = 0;
input double inpMinCorrel = 0.85;
input int    inpMinSizePCT = 80;
int patternSizePts = 0;
MqlTick tick;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   if(loadPattern() == false)
     {
      return INIT_FAILED;
     }
   drawPattern();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(!isNewBar())
     {
      return;
     }
   if(!SymbolInfoTick(_Symbol, tick))
     {
      return;
     }

// get close price
   double closeArr[];
   CopyClose(_Symbol,_Period, 1, patternBars, closeArr);

// calculate correlation
   double correl;
   if(!MathCorrelationPearson(pattern, closeArr, correl))
     {
      Print("Failed to correlate");
      return;
     }

   double sizePts = (closeArr[ArrayMaximum(closeArr)]-closeArr[ArrayMinimum(closeArr)]) / _Point;
   double sizePct = sizePts / (double)patternSizePts * 100;

   drawPattern();

   if((correl > inpMinCorrel || correl < -inpMinCorrel) && sizePct >= inpMinSizePCT)
     {
      Print("Correlation " + DoubleToString(correl, 2));
      DrawMark(correl > inpMinCorrel);
     }
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool loadPattern()
  {

   int handleFile = FileOpen("pattern.csv", FILE_READ | FILE_ANSI | FILE_CSV, "\t");
   if(handleFile == INVALID_HANDLE)
     {
      Print("prout");
      Print("Operation FileOpen failed, error ",GetLastError());
      return false;
     }

   int line = 0;
   int col  = 0;

   while(!FileIsEnding(handleFile))
     {
      string str = FileReadString(handleFile);

      if(line > 0 && col == 6)
        {
         int size = ArraySize(pattern);
         ArrayResize(pattern, size+1);
         pattern[size] = StringToDouble(str);
        }
      if(FileIsLineEnding(handleFile))
        {
         line++;
         col=0;
        }
      col++;
     }

   patternBars = ArraySize(pattern);
   patternSizePts = (int)(pattern[ArrayMaximum(pattern)]-pattern[ArrayMinimum(pattern)]) / _Point;

   FileClose(handleFile);

   return true;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void drawPattern()
  {
   for(int i = 0 ; i < patternBars; i++)
     {
      string pat = "patlegan" + (string)i;
      ObjectCreate(0, pat,OBJ_ARROW, 0, iTime(_Symbol, _Period, patternBars-i),
                   pattern[i] - (pattern[patternBars-1]-iClose(_Symbol,_Period,1)));


      ObjectSetInteger(0, pat,OBJPROP_COLOR,clrBlueViolet);
      ObjectSetString(0, pat, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(0, pat,OBJPROP_ARROWCODE, 159);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
  {

   static datetime previoustime = 0;
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(previoustime != currentTime)
     {
      return true;
     }

   return false;

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawMark(bool isBuy = true)
  {
   for(int i = 0 ; i < patternBars; i++)
     {
      string pat = "MarkLenfant" + TimeToString(TimeCurrent());
      ObjectCreate(0, pat,OBJ_VLINE, 0, TimeCurrent(),0);


      ObjectSetInteger(0, pat,OBJPROP_COLOR,clrOrange);
      ObjectSetString(0, pat, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(0, pat,OBJPROP_ARROWCODE, 159);
     }

   for(int i = 0 ; i < patternBars; i++)
     {
     
      double offset = pattern[patternBars-1]-iClose(_Symbol,_Period,1);
      string pat = "patlegan" + TimeToString(TimeCurrent()) + (string)i;
      ObjectCreate(0, pat,OBJ_ARROW, 0, iTime(_Symbol, _Period, patternBars-i),
                   isBuy == true ? pattern[i] - offset
                   : pattern[i] - offset + 2 * ((iClose(_Symbol,_Period,1) - (pattern[i] - offset))));


      ObjectSetInteger(0, pat,OBJPROP_COLOR,clrBlueViolet);
      ObjectSetString(0, pat, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(0, pat,OBJPROP_ARROWCODE, 159);
     }

  }
//+------------------------------------------------------------------+
