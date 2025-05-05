//+------------------------------------------------------------------+
//|                                                      helpers.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+

#include "OBStruct.mqh";


// Add this function to create the folder if it doesn't exist
bool CreateFolderIfNeeded(string folder)
  {

   StringReplace(folder,"/", "");
   Print("Try to create folder "+ folder);
   if(!FolderCreate(folder))
     {
      Print("Failed to create folder: ", folder, " Error: ", GetLastError());
      return false;

     }
   else
     {
      Print("Folder Created");
     }

   Print("Try to create folder "+ folder + "/" + _Symbol);
   if(!FolderCreate(folder+ "/" + _Symbol))
     {
      Print("Failed to create folder: ", folder+ "/" + _Symbol, " Error: ", GetLastError());
      return false;

     }
   else
     {
      Print("Folder Created");
     }


   Print("Try to create folder "+ folder + "/" + _Symbol + "/tp");
   if(!FolderCreate(folder + "/" + _Symbol + "/tp"))
     {
      Print("Failed to create folder: ", folder + "/" + _Symbol + "/tp", " Error: ", GetLastError());
      return false;

     }
   else
     {
      Print("Folder Created");
     }

   Print("Try to create folder "+ folder + "/" + _Symbol + "/sl");
   if(!FolderCreate(folder + "/" + _Symbol + "/sl"))
     {
      Print("Failed to create folder: ", folder + "/" + _Symbol + "/sl", " Error: ", GetLastError());
      return false;

     }
   else
     {
      Print("Folder Created");
     }

   return true;
  }

//+------------------------------------------------------------------+
void sendNotif(string message)
  {

//--- check permission to send notifications in the terminal
   if(!TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
     {
      Print("Error. The client terminal does not have permission to send notifications");
      return;
     }
//--- send notification
   ResetLastError();
   if(!SendNotification(message))
      Print("SendNotification() failed. Error ",GetLastError());
  }


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int gap_y=15;
   if(ObjectFind(0,m_dayly_profit_name)<0)
      LabelCreate(0,m_dayly_profit_name,0,InpX,InpY,CORNER_LEFT_UPPER,"Daily Profit: "+"(%)",InpFont,InpFontSize);
   if(ObjectFind(0,m_weekly_profit_name)<0)
      LabelCreate(0,m_weekly_profit_name,0,InpX,InpY+gap_y,CORNER_LEFT_UPPER,"Weekly Profit: "+"(%)",InpFont,InpFontSize);
   if(ObjectFind(0,m_monthly_profit_name)<0)
      LabelCreate(0,m_monthly_profit_name,0,InpX,InpY+gap_y*2,CORNER_LEFT_UPPER,"Monthly Profit: "+"(%)",InpFont,InpFontSize);
//---
   if(ObjectFind(0,m_dayly_deals_name)<0)
      LabelCreate(0,m_dayly_deals_name,0,InpX,InpY+gap_y*3,CORNER_LEFT_UPPER,"Daily Deals: "+"(%)",InpFont,InpFontSize);
   if(ObjectFind(0,m_weekly_deals_name)<0)
      LabelCreate(0,m_weekly_deals_name,0,InpX,InpY+gap_y*4,CORNER_LEFT_UPPER,"Weekly Deals: "+"(%)",InpFont,InpFontSize);
   if(ObjectFind(0,m_monthly_deals_name)<0)
      LabelCreate(0,m_monthly_deals_name,0,InpX,InpY+gap_y*5,CORNER_LEFT_UPPER,"Monthly Deals: "+"(%)",InpFont,InpFontSize);

//---
   ProfitForPeriod();
  }
//+------------------------------------------------------------------+
//| Create a text label                                              |
//+------------------------------------------------------------------+
bool LabelCreate(const long              chart_ID=0,               // chart's ID
                 const string            name="Label",             // label name
                 const int               sub_window=0,             // subwindow index
                 const int               x=0,                      // X coordinate
                 const int               y=0,                      // Y coordinate
                 const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
                 const string            text="Label",             // text
                 const string            font="Arial",             // font
                 const int               font_size=6,             // font size
                 const color             clr=clrWhite,               // color
                 const double            angle=0.0,                // text slope
                 const ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER, // anchor type
                 const bool              back=false,               // in the background
                 const bool              selection=false,          // highlight to move
                 const bool              hidden=true,              // hidden in the object list
                 const long              z_order=0)                // priority for mouse click
  {
//--- reset the error value
   ResetLastError();
//--- create a text label
   if(!ObjectCreate(chart_ID,name,OBJ_LABEL,sub_window,0,0))
     {
      Print(__FUNCTION__,
            ": failed to create text label! Error code = ",GetLastError());
      return(false);
     }
//--- set label coordinates
   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
//--- set the text
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);
//--- set text font
   ObjectSetString(chart_ID,name,OBJPROP_FONT,font);
//--- set font size
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
//--- set the slope angle of the text
   ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,angle);
//--- set anchor type
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
//--- set color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Change the label text                                            |
//+------------------------------------------------------------------+
bool LabelTextChange(const long   chart_ID=0,   // chart's ID
                     const string name="Label", // object name
                     const string text="Text")  // text
  {
//--- reset the error value
   ResetLastError();
//--- change object text
   if(!ObjectSetString(chart_ID,name,OBJPROP_TEXT,text))
     {
      Print(__FUNCTION__,
            ": failed to change the text! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Profit for the period                                            |
//+------------------------------------------------------------------+
void ProfitForPeriod(void)
  {
   datetime time_trade_server = TimeTradeServer();
   datetime from_date         = time_trade_server;
   datetime to_date           = time_trade_server+60*60*24*3;
   datetime from_date_day     = time_trade_server;
   datetime from_date_week    = time_trade_server;
   MqlDateTime STime;
   TimeToStruct(time_trade_server,STime);
//--- subtract time in seconds from the estimated time of the trade server - we get the time of day
   if(STime.day_of_week==0) // if it's Sunday - we subtract two days
      from_date_day=time_trade_server-60*60*24*2;
   if(STime.day_of_week==6) // if it's Saturday, we subtract the day
      from_date_day=time_trade_server-60*60*24;
   TimeToStruct(from_date_day,STime);
   STime.hour=0;
   STime.min=0;
   STime.sec=0;
   from_date_day=StructToTime(STime);           // start time of the last day (Monday to Friday)
//--- remember the current month
   TimeToStruct(from_date_day,STime);
   int curr_mon=STime.mon;
//--- takes time from the time of day in seconds - we get the time of the week
   if(STime.day_of_week==1)
      from_date_week=from_date_day;
   if(STime.day_of_week==2)
      from_date_week=from_date_day-60*60*24;    // minus day
   if(STime.day_of_week==3)
      from_date_week=from_date_day-60*60*24*2;  // minus two days
   if(STime.day_of_week==4)
      from_date_week=from_date_day-60*60*24*3;  // minus three days
   if(STime.day_of_week==5)
      from_date_week=from_date_day-60*60*24*4;  // minus four days
   TimeToStruct(from_date_week,STime);
//--- checking if we stayed in the current month (relative to the time of day)
   if(STime.mon!=curr_mon)
     {
      STime.mon=STime.mon+1;
      STime.day=1;
      from_date_week=StructToTime(STime);
      from_date=from_date_week;
     }
   else // remained in the current month
     {
      STime.day=1;
      from_date=StructToTime(STime);
     }
//--- request trade history
   HistorySelect(from_date,to_date);
//---
   uint     total=HistoryDealsTotal();
   ulong    ticket=0;
   long     position_id=0;
   double   profit_monthly=0.0,profit_weekly=0.0,profit_dayly=0.0;
   int      deals_monthly=0,deals_weekly=0,deals_dayly=0;
//--- for all deals
   for(uint i=0; i<total; i++) // for(uint i=0;i<total;i++) => i #0 - 2016, i #1045 - 2017
     {
      //--- try to get deals ticket
      if((ticket=HistoryDealGetTicket(i))>0)
        {
         //--- get deals properties
         long     deal_time         = HistoryDealGetInteger(ticket,DEAL_TIME);
         long     deal_type         = HistoryDealGetInteger(ticket,DEAL_TYPE);
         long     deal_entry        = HistoryDealGetInteger(ticket,DEAL_ENTRY);
         long     deal_magic        = HistoryDealGetInteger(ticket,DEAL_MAGIC);
         //---
         double   deal_commission   = HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         double   deal_swap         = HistoryDealGetDouble(ticket,DEAL_SWAP);
         double   deal_profit       = HistoryDealGetDouble(ticket,DEAL_PROFIT);
         //---
         string   deal_symbol       = HistoryDealGetString(ticket,DEAL_SYMBOL);
         //--- only for input symbol and magic
         //         if(deal_symbol==InpSymbol && deal_magic==InpMagic)
         if((ENUM_DEAL_TYPE)deal_type==DEAL_TYPE_BUY || (ENUM_DEAL_TYPE)deal_type==DEAL_TYPE_SELL)
           {
            double profit=deal_commission+deal_swap+deal_profit;
            profit_monthly+=profit;
            deals_monthly++;
            if(deal_time>=from_date_week)
              {
               profit_weekly+=profit;
               deals_weekly++;
              }
            if(deal_time>=from_date_day)
              {
               profit_dayly+=profit;
               deals_dayly++;
              }
           }
        }
     }
   double curr_balance=AccountInfoDouble(ACCOUNT_BALANCE);
   /*
   prev. balance                 - 100%
   prev. balance + profit        - x%

   dayly_prev_balance            - 100%
   curr_balance                  - x%
   x = 100.0-(curr_balance*100.0/dayly_prev_balance)
   */
   double dayly_prev_balance     = curr_balance-profit_dayly;
   double weekly_prev_balance    = curr_balance-profit_weekly;
   double monthly_prev_balance   = curr_balance-profit_monthly;
   string currency=AccountInfoString(ACCOUNT_CURRENCY);
//---
   LabelTextChange(0,m_dayly_profit_name,"Daily Profit:     "+currency+" "+DoubleToString(profit_dayly,2)+
                   " ("+DoubleToString((curr_balance*100.0/dayly_prev_balance)-100.0,2)+"%)");
   LabelTextChange(0,m_weekly_profit_name,"Weekly Profit:    "+currency+" "+DoubleToString(profit_weekly,2)+
                   " ("+DoubleToString((curr_balance*100.0/weekly_prev_balance)-100.0,2)+"%)");
   LabelTextChange(0,m_monthly_profit_name,"Monthly Profit:   "+currency+" "+DoubleToString(profit_monthly,2)+
                   " ("+DoubleToString((curr_balance*100.0/monthly_prev_balance)-100.0,2)+"%)");
//---
   LabelTextChange(0,m_dayly_deals_name,"Daily Deals:      "+IntegerToString(deals_dayly));
   LabelTextChange(0,m_weekly_deals_name,"Weekly Deals:     "+IntegerToString(deals_weekly));
   LabelTextChange(0,m_monthly_deals_name,"Monthly Deals:    "+IntegerToString(deals_monthly));
//---
   return;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|   Return in icon amount of stars                                 |
//+------------------------------------------------------------------+
string getStars(int a)
  {
   string stars = "";
   if(obBuffer[a].stars == 0)
      return "X";
   for(int i = 0; i < obBuffer[a].stars; i++)
     {
      stars = stars + CharToString(171);
     }

   return stars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double high(int index) {return (iHigh(_Symbol,_Period,index));}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double low(int index) {return (iLow(_Symbol,_Period,index));}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double close(int index) {return (iClose(_Symbol,_Period,index));}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime time(int index) {return (iTime(_Symbol,_Period,index));}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| IF OB has already been found                                     |
//+------------------------------------------------------------------+
bool alreadyFound()
  {
   for(int a = 0; a < ArraySize(obBuffer); a++)
     {
      if(obBuffer[a].startTime == rA[1].time)
        {
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string helperTrend(bool direction)
  {
   if(direction == true)
      return "up";
   return "down";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int candleSize(double open, double close)
  {
   return MathAbs((open - close)*1/Point());
  }

//+------------------------------------------------------------------+
//| Check if an OB is already occuring on the same time
//| above (bearish) or below (bullish)
//+------------------------------------------------------------------+
bool isFirstOB(int i = 0)
  {
   int arrSize = ArraySize(obBuffer);
   if(arrSize < 2)
     {
      return true ;
     }
   for(int a = 0; a < ArraySize(obBuffer); a++)
     {
      if(a != i &&
         obBuffer[a].startTime < obBuffer[i].startTime && // the tested is newer
         obBuffer[a].isBear == obBuffer[i].isBear &&
         obBuffer[a].stars >= 2 // if 0 stars doesn t count
        )
        {
         if( obBuffer[a].isBear == false && obBuffer[a].highPrice < obBuffer[i].highPrice){
           return false;
         }
         if( obBuffer[a].isBear == true && obBuffer[a].lowPrice > obBuffer[i].lowPrice){
           return false;
         }
        }
     }
   return true;
  }
  
 //+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool timeToTrade()
  {
   MqlDateTime mdt;
   TimeCurrent(mdt);

   if(forbidMondayFriday == true)
     {
      if(mdt.day_of_week == 1 || mdt.day_of_week == 5)
        {
         return false;
        }
     }

   if(mdt.hour >= 9 && mdt.hour <= 18)
     {
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|     Delete objects                                               |
//+------------------------------------------------------------------+
void cleanObjects(int a)
  {
   ObjectDelete(0, obBuffer[a].name + "-lqLine");
   ObjectDelete(0, obBuffer[a].name + "-ImLine");
   ObjectDelete(0, obBuffer[a].name + "-ImVal");
   ObjectDelete(0, obBuffer[a].name + "-fib127");
   ObjectDelete(0, obBuffer[a].name + "-fib161");
   ObjectDelete(0, obBuffer[a].name + "-fib232");
   ObjectDelete(0, obBuffer[a].name + "-mitiline");
   ObjectDelete(0, obBuffer[a].name + "-50");
   ObjectDelete(0, obBuffer[a].name + "-sl");
   ObjectDelete(0, obBuffer[a].name);
   ObjectDelete(0, obBuffer[a].name + "-text");
   ObjectDelete(0, obBuffer[a].name + "-prevhigh");
   ObjectDelete(0, obBuffer[a].name + "-prevlow");
  }


//+------------------------------------------------------------------+
//| Check if an OB has still a openned position                      |
//+------------------------------------------------------------------+
bool hasOnGoingPosition(int a)
  {
   if(PositionSelectByTicket(obBuffer[a].tradeTicket) == true)
     {
      Print("A position is still running");
      return true;
     }

   return false;
  }


void preventOverExtention(int i){
// Get point size and pip value
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   double pipValue = digits == 3 || digits == 5 ? point * 10 : point;
   int OrderBlockCandleIndex = iBarShift(_Symbol,HTOB,obBuffer[i].startTime);
   
   // Calculate order block body size in pips
   double obBodySizePips = MathAbs(obBuffer[i].highPrice - obBuffer[i].lowPrice) / pipValue;
   
   // Get ATR for volatility context
   double atr = iATR(_Symbol, HTOB, ATRPeriod) / pipValue;
   
   // Find the highest high after the order block within LookbackCandles
   double highestHigh = obBuffer[i].highPrice;
   int highestIndex = OrderBlockCandleIndex;
   
   // Bearish order
   if (obBuffer[i].isBear  == true && iLow(_Symbol,HTOB,0) < highestHigh){
      highestHigh = iLow(_Symbol,HTOB,0);
   }
   
   if (obBuffer[i].isBear  == false && iHigh(_Symbol,HTOB,0) > highestHigh) { // bullish order
      highestHigh = iHigh(_Symbol,HTOB,0);
   }
   
   double OBLowPrice = (obBuffer[i].isBear == true) ? obBuffer[i].highPrice: obBuffer[i].lowPrice;
   // Calculate the bullish move size in pips
   double bullishMovePips = MathAbs(highestHigh - OBLowPrice) / pipValue;
   
   // Check if the bullish move was excessive
   bool isOverextended = bullishMovePips > MaxMoveATRFactor * atr;
   
   if (isOverextended == true){
      obBuffer[i].isDone= true;
      obBuffer[i].stars = 0;
   
   // Output results
   string result = StringFormat("Bullish Order Block Analysis (Candle %d):\n", OrderBlockCandleIndex);
   result += StringFormat("Body Size: %.2f pips\n", obBodySizePips);
   result += StringFormat("Bullish Move to High: %.2f pips (at candle %d)\n", bullishMovePips, highestIndex);
   result += StringFormat("ATR (%d periods): %.2f pips\n", ATRPeriod, atr);
   result += isOverextended ? "WARNING: Excessive bullish move (> 3x ATR)\n" : "Bullish move within normal range\n";
   
      Print(result);
   }

}

// TEST liquidity SWEEP
// Swing low sweep detector inside OB lifespan
//+------------------------------------------------------------------+
//| Function to detect and mark liquidity sweeps within OB timeframe |
//+------------------------------------------------------------------+
bool DetectLiquiditySweep(datetime orderBlockTime , int lookbackPeriod=20, int sweepCheckBars=10)
{
   // Get the index of the order block candle
   int obIndex = iBarShift(_Symbol, HTOB, orderBlockTime, true);
   if(obIndex == -1)
   {
      Print("Error: Invalid order block datetime");
      return false;
   }

   // Get high and low of the order block candle
   double obHigh = iHigh(_Symbol, HTOB, obIndex);
   double obLow = iLow(_Symbol, HTOB, obIndex);
   datetime obEndTime = iTime(_Symbol, HTOB, 0); // Extend to next candle for rectangle

   // Check for liquidity sweep
   bool sweepDetected = false;
   string sweepType = "";
   double sweepPrice = 0.0;
   datetime sweepTime = 0;

   for(int i = obIndex - 1; i >= obIndex - sweepCheckBars && i >= 0; i--)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, i);

      // Check for sweep above high
      if(high > obHigh)
      {
         // Verify reversal (next few candles close below high)
         for(int j = i - 1; j >= i - 3 && j >= 0; j--)
         {
            if(iClose(_Symbol, PERIOD_CURRENT, j) < obHigh)
            {
               sweepDetected = true;
               sweepType = "High";
               sweepPrice = high;
               sweepTime = currentTime;
               break;
            }
         }
         if(sweepDetected) break;
      }
      // Check for sweep below low
      else if(low < obLow)
      {
         // Verify reversal (next few candles close above low)
         for(int j = i - 1; j >= i - 3 && j >= 0; j--)
         {
            if(iClose(_Symbol, PERIOD_CURRENT, j) > obLow)
            {
               sweepDetected = true;
               sweepType = "Low";
               sweepPrice = low;
               sweepTime = currentTime;
               break;
            }
         }
         if(sweepDetected) break;
      }
   }

   // Draw sweep zone if detected
   if(sweepDetected)
   {
      string sweepName = "Sweep_" + TimeToString(sweepTime);
      double sweepHigh, sweepLow;
      datetime sweepEndTime = iTime(_Symbol, HTOB, MathMax(0, iBarShift(_Symbol, HTOB, sweepTime) - 1));

      if(sweepType == "High")
      {
         sweepHigh = sweepPrice;
         sweepLow = obHigh;
      }
      else
      {
         sweepHigh = obLow;
         sweepLow = sweepPrice;
      }

      if(!ObjectCreate(0, sweepName, OBJ_RECTANGLE, 0, sweepTime, sweepHigh, sweepEndTime, sweepLow))
      {
         Print("Error creating sweep rectangle: ", GetLastError());
         return false;
      }
      ObjectSetInteger(0, sweepName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sweepName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, sweepName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, sweepName, OBJPROP_FILL, true);
      ObjectSetInteger(0, sweepName, OBJPROP_BACK, true);
      Print("Liquidity sweep detected at ", sweepType, " of order block at ", TimeToString(orderBlockTime));
      return true;
   }
   else
   {
      Print("No liquidity sweep detected for order block at ", TimeToString(orderBlockTime));
   }

   return false;
}