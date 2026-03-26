//+------------------------------------------------------------------+
//|                                              VolumeProfile.mq5    |
//|                        Copyright 2026, Charles-Antoine Fournel   |
//|                                             https://orderblock.io|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Charles-Antoine Fournel"
#property link      "https://orderblock.io"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   4

enum ENUM_PROFILE_MODE
{
   MODE_SESSION,     // Session-based (D1 default)
   MODE_FIXED_RANGE, // Fixed lookback bars
   MODE_VISIBLE     // Visible chart range
};

enum ENUM_PROFILE_TYPE
{
   TYPE_VOLUME_PROFILE, // Standard Volume Profile
   TYPE_DELTA_PROFILE,  // Delta (buy/sell) Profile
   TYPE_TPO_PROFILE    // Time Price Opportunity
};

input group "=== Profile Settings ==="
input ENUM_PROFILE_MODE ProfileMode = MODE_SESSION;    // Profile Calculation Mode
input ENUM_PROFILE_TYPE ProfileType = TYPE_VOLUME_PROFILE; // Profile Type
input int              LookbackBars = 100;              // Lookback Bars (for Fixed Range)
input double           TicksPerRow = 100;               // Price step per row (in points)
input int              ValueAreaPercent = 70;           // Value Area % (typically 68-80)

input group "=== Session Settings ==="
input bool             UseCustomSession = false;        // Use Custom Session Hours
input int              SessionStartHour = 0;            // Session Start Hour (UTC)
input int              SessionEndHour = 24;             // Session End Hour (UTC)

input group "=== Display Settings ==="
input bool             ShowPOC = true;                // Show Point of Control
input bool             ShowVA = true;                  // Show Value Area
input bool             ShowProfile = false;            // Show Volume Histogram
input bool             ShowLabels = true;              // Show Price Labels
input bool             ShowCurrentSession = false;       // Highlight Current Session
input bool             FillCurrentSession = false;       // Fill Current Session (vs perimeter only)
input int              MaxRowsDisplay = 100;           // Max Rows to Display

input group "=== Colors ==="
input color            POC_Color = clrYellow;          // POC Line Color
input color            VAH_Color = clrLime;            // VAH Line Color
input color            VAL_Color = clrRed;              // VAL Line Color
input color            ProfileBull_Color = clrGreen;    // Bullish Profile Color
input color            ProfileBear_Color = clrMaroon;   // Bearish Profile Color
input color            HVN_Color = clrOrange;           // High Volume Node Color
input color            LVN_Color = clrCornflowerBlue;   // Low Volume Node Color

input group "=== Style ==="
input ENUM_LINE_STYLE  LineStyle = STYLE_SOLID;        // Line Style
input int              LineWidth = 2;                   // Line Width

double BufferPOC[];
double BufferVAH[];
double BufferVAL[];
double BufferHVN[];
double BufferLVN[];
double BufferProfile[];
double BufferDelta[];

struct PriceLevel
{
   double price;
   double volume;
   double buyVolume;
   double sellVolume;
   int    ticks;
   int    tpoCount;
};

struct ProfileData
{
   datetime   startTime;
   datetime   endTime;
   double     pocPrice;
   double     vahPrice;
   double     valPrice;
   double     totalVolume;
   double     buyVolume;
   double     sellVolume;
   int        pocIndex;
   PriceLevel levels[];
};

ProfileData g_currentProfile;
datetime g_lastProfileTime = 0;

int OnInit()
{
   SetIndexBuffer(0, BufferPOC, INDICATOR_DATA);
   SetIndexBuffer(1, BufferVAH, INDICATOR_DATA);
   SetIndexBuffer(2, BufferVAL, INDICATOR_DATA);
   SetIndexBuffer(3, BufferHVN, INDICATOR_DATA);
   SetIndexBuffer(4, BufferLVN, INDICATOR_DATA);
   SetIndexBuffer(5, BufferProfile, INDICATOR_DATA);
   SetIndexBuffer(6, BufferDelta, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, POC_Color);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, LineStyle);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, LineWidth);
   
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, VAH_Color);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, STYLE_DASH);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, VAL_Color);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, STYLE_DASH);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, 1);
   
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);

   IndicatorSetString(INDICATOR_SHORTNAME, "VolumeProfile");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   ArraySetAsSeries(BufferPOC, true);
   ArraySetAsSeries(BufferVAH, true);
   ArraySetAsSeries(BufferVAL, true);
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "VP_", 0, -1);
   ObjectsDeleteAll(0, "VP_POC", 0, -1);
   ObjectsDeleteAll(0, "VP_VA", 0, -1);
   ObjectsDeleteAll(0, "VP_Profile", 0, -1);
}

bool GetProfileRange(datetime &startTime, datetime &endTime)
{
   MqlDateTime dtStruct;
   TimeToStruct(TimeCurrent(), dtStruct);
   
   if(ProfileMode == MODE_SESSION)
   {
      if(UseCustomSession)
      {
         dtStruct.hour = SessionStartHour;
         dtStruct.min = 0;
         dtStruct.sec = 0;
         startTime = StructToTime(dtStruct);
         
         if(SessionEndHour < SessionStartHour)
            dtStruct.day += 1;
         dtStruct.hour = SessionEndHour;
         dtStruct.min = 0;
         dtStruct.sec = 0;
         endTime = StructToTime(dtStruct);
      }
      else
      {
         dtStruct.hour = 0;
         dtStruct.min = 0;
         dtStruct.sec = 0;
         startTime = StructToTime(dtStruct);
         
         dtStruct.hour = 23;
         dtStruct.min = 59;
         dtStruct.sec = 59;
         endTime = StructToTime(dtStruct);
      }
   }
   else if(ProfileMode == MODE_FIXED_RANGE)
   {
      endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      startTime = iTime(_Symbol, PERIOD_CURRENT, LookbackBars);
   }
   else // MODE_VISIBLE
   {
      long chartFirst = 0, chartWidth = 0;
      ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0, chartFirst);
      ChartGetInteger(0, CHART_WIDTH_IN_BARS, 0, chartWidth);
      startTime = iTime(_Symbol, PERIOD_CURRENT, (int)chartFirst);
      endTime = iTime(_Symbol, PERIOD_CURRENT, (int)(chartFirst + chartWidth - 1));
   }
   
   return (startTime > 0 && endTime > startTime);
}

void BuildProfile()
{
   datetime startTime, endTime;
   if(!GetProfileRange(startTime, endTime))
      return;
   
   int startBar = iBarShift(_Symbol, PERIOD_CURRENT, startTime);
   int endBar = iBarShift(_Symbol, PERIOD_CURRENT, endTime);
   
   if(startBar < 0 || endBar < 0 || startBar <= endBar)
      return;
   
   int totalBars = startBar - endBar;
   if(totalBars <= 0)
      return;
   
   double tickSize = TicksPerRow * _Point;
   if(tickSize <= 0)
      tickSize = _Point;
   
   double prices[];
   double volumes[];
   double buys[];
   double sells[];
   
   ArraySetAsSeries(prices, true);
   ArraySetAsSeries(volumes, true);
   ArraySetAsSeries(buys, true);
   ArraySetAsSeries(sells, true);
   
   int size = CopyClose(_Symbol, PERIOD_CURRENT, endBar, totalBars, prices);
   if(size <= 0)
      return;
   
   ArrayResize(volumes, size);
   ArrayResize(buys, size);
   ArrayResize(sells, size);
   
   long tickVol[];
   ArraySetAsSeries(tickVol, true);
   
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, endBar, totalBars, tickVol) <= 0)
   {
      ArrayInitialize(volumes, 1.0);
   }
   else
   {
      for(int i = 0; i < size; i++)
         volumes[i] = (double)tickVol[i];
   }
   
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, endBar, totalBars, rates) > 0)
   {
      for(int i = 0; i < size && i < ArraySize(rates); i++)
      {
         if(rates[i].close >= rates[i].open)
         {
            buys[i] = volumes[i];
            sells[i] = volumes[i] * 0.5;
         }
         else
         {
            sells[i] = volumes[i];
            buys[i] = volumes[i] * 0.5;
         }
      }
   }
   
   double minPrice = prices[ArrayMinimum(prices)];
   double maxPrice = prices[ArrayMaximum(prices)];
   
   minPrice = MathFloor(minPrice / tickSize) * tickSize;
   maxPrice = MathCeil(maxPrice / tickSize) * tickSize;
   
   int numRows = (int)MathCeil((maxPrice - minPrice) / tickSize) + 1;
   if(numRows > MaxRowsDisplay)
   {
      tickSize = (maxPrice - minPrice) / MaxRowsDisplay;
      numRows = MaxRowsDisplay;
   }
   
   PriceLevel rows[];
   ArrayResize(rows, numRows);
   
   for(int i = 0; i < numRows; i++)
   {
      rows[i].price = minPrice + i * tickSize;
      rows[i].volume = 0;
      rows[i].buyVolume = 0;
      rows[i].sellVolume = 0;
      rows[i].ticks = 0;
      rows[i].tpoCount = 0;
   }
   
   for(int i = 0; i < size; i++)
   {
      int rowIndex = (int)((prices[i] - minPrice) / tickSize);
      if(rowIndex >= 0 && rowIndex < numRows)
      {
         rows[rowIndex].volume += volumes[i];
         rows[rowIndex].buyVolume += buys[i];
         rows[rowIndex].sellVolume += sells[i];
         rows[rowIndex].ticks++;
         rows[rowIndex].tpoCount++;
      }
   }
   
   double totalVolume = 0;
   double totalBuy = 0;
   double totalSell = 0;
   for(int i = 0; i < numRows; i++)
   {
      totalVolume += rows[i].volume;
      totalBuy += rows[i].buyVolume;
      totalSell += rows[i].sellVolume;
   }
   
   int pocIndex = 0;
   double maxVol = 0;
   for(int i = 0; i < numRows; i++)
   {
      if(rows[i].volume > maxVol)
      {
         maxVol = rows[i].volume;
         pocIndex = i;
      }
   }
   
   double targetVolume = totalVolume * (ValueAreaPercent / 100.0) / 2.0;
   
   int vahIndex = pocIndex;
   double aboveVol = 0;
   for(int i = pocIndex + 1; i < numRows; i++)
   {
      aboveVol += rows[i].volume;
      vahIndex = i;
      if(aboveVol >= targetVolume)
         break;
   }
   
   int valIndex = pocIndex;
   double belowVol = 0;
   for(int i = pocIndex - 1; i >= 0; i--)
   {
      belowVol += rows[i].volume;
      valIndex = i;
      if(belowVol >= targetVolume)
         break;
   }
   
   g_currentProfile.startTime = startTime;
   g_currentProfile.endTime = endTime;
   g_currentProfile.pocPrice = rows[pocIndex].price;
   g_currentProfile.vahPrice = rows[vahIndex].price;
   g_currentProfile.valPrice = rows[valIndex].price;
   g_currentProfile.totalVolume = totalVolume;
   g_currentProfile.buyVolume = totalBuy;
   g_currentProfile.sellVolume = totalSell;
   g_currentProfile.pocIndex = pocIndex;
   ArrayResize(g_currentProfile.levels, numRows);
   ArrayCopy(g_currentProfile.levels, rows);
   
   double avgVol = totalVolume / numRows;
   double stdDev = 0;
   for(int i = 0; i < numRows; i++)
   {
      stdDev += MathPow(rows[i].volume - avgVol, 2);
   }
   stdDev = MathSqrt(stdDev / numRows);
   
   for(int i = 0; i < numRows; i++)
   {
      if(rows[i].volume > avgVol + stdDev * 0.5)
         BufferHVN[i] = rows[i].price;
      else
         BufferHVN[i] = EMPTY_VALUE;
      
      if(rows[i].volume < avgVol * 0.3 && rows[i].volume > 0)
         BufferLVN[i] = rows[i].price;
      else
         BufferLVN[i] = EMPTY_VALUE;
   }
   
   g_lastProfileTime = TimeCurrent();
}

void DrawProfile()
{
   string prefix = "VP_";
   
   if(ShowPOC)
   {
      string pocName = prefix + "POC_" + IntegerToString((int)g_currentProfile.startTime);
      if(ObjectFind(0, pocName) < 0)
      {
         ObjectCreate(0, pocName, OBJ_HLINE, 0, 0, g_currentProfile.pocPrice);
         ObjectSetInteger(0, pocName, OBJPROP_COLOR, POC_Color);
         ObjectSetInteger(0, pocName, OBJPROP_STYLE, LineStyle);
         ObjectSetInteger(0, pocName, OBJPROP_WIDTH, LineWidth);
         ObjectSetString(0, pocName, OBJPROP_TEXT, "POC");
      }
      else
      {
         ObjectSetDouble(0, pocName, OBJPROP_PRICE, g_currentProfile.pocPrice);
      }
      
      if(ShowLabels)
      {
         string labelName = prefix + "POC_Label_" + IntegerToString((int)g_currentProfile.startTime);
         if(ObjectFind(0, labelName) < 0)
         {
            ObjectCreate(0, labelName, OBJ_TEXT, 0, 0, g_currentProfile.pocPrice);
            ObjectSetString(0, labelName, OBJPROP_TEXT, "POC");
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, POC_Color);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         }
         else
         {
            ObjectSetDouble(0, labelName, OBJPROP_PRICE, g_currentProfile.pocPrice);
         }
      }
   }
   
   if(ShowVA)
   {
      string vahName = prefix + "VAH_" + IntegerToString((int)g_currentProfile.startTime);
      if(ObjectFind(0, vahName) < 0)
      {
         ObjectCreate(0, vahName, OBJ_HLINE, 0, 0, g_currentProfile.vahPrice);
         ObjectSetInteger(0, vahName, OBJPROP_COLOR, VAH_Color);
         ObjectSetInteger(0, vahName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, vahName, OBJPROP_WIDTH, 1);
      }
      else
      {
         ObjectSetDouble(0, vahName, OBJPROP_PRICE, g_currentProfile.vahPrice);
      }
      
      string valName = prefix + "VAL_" + IntegerToString((int)g_currentProfile.startTime);
      if(ObjectFind(0, valName) < 0)
      {
         ObjectCreate(0, valName, OBJ_HLINE, 0, 0, g_currentProfile.valPrice);
         ObjectSetInteger(0, valName, OBJPROP_COLOR, VAL_Color);
         ObjectSetInteger(0, valName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, valName, OBJPROP_WIDTH, 1);
      }
      else
      {
         ObjectSetDouble(0, valName, OBJPROP_PRICE, g_currentProfile.valPrice);
      }
      
      string vaBoxName = prefix + "VA_Box_" + IntegerToString((int)g_currentProfile.startTime);
      double vaTop = MathMax(g_currentProfile.vahPrice, g_currentProfile.valPrice);
      double vaBottom = MathMin(g_currentProfile.vahPrice, g_currentProfile.valPrice);
      
      if(ObjectFind(0, vaBoxName) < 0)
      {
         if(ObjectCreate(0, vaBoxName, OBJ_RECTANGLE, 0, g_currentProfile.startTime, vaTop))
         {
            ObjectSetInteger(0, vaBoxName, OBJPROP_COLOR, VAH_Color);
            ObjectSetInteger(0, vaBoxName, OBJPROP_FILL, true);
            ObjectSetInteger(0, vaBoxName, OBJPROP_BACK, true);
            ObjectSetDouble(0, vaBoxName, OBJPROP_PRICE, vaTop);
            ObjectSetDouble(0, vaBoxName, OBJPROP_PRICE, vaBottom);
            ObjectSetInteger(0, vaBoxName, OBJPROP_TIME, g_currentProfile.endTime);
         }
      }
      else
      {
         ObjectSetDouble(0, vaBoxName, OBJPROP_PRICE, vaTop);
         ObjectSetDouble(0, vaBoxName, OBJPROP_PRICE, vaBottom);
      }
      
      if(ShowLabels)
      {
         datetime labelTime = g_currentProfile.endTime;
         string vahLabel = prefix + "VAH_Label";
         if(ObjectFind(0, vahLabel) < 0)
         {
            ObjectCreate(0, vahLabel, OBJ_TEXT, 0, labelTime, g_currentProfile.vahPrice);
            ObjectSetString(0, vahLabel, OBJPROP_TEXT, "VAH");
            ObjectSetInteger(0, vahLabel, OBJPROP_COLOR, VAH_Color);
         }
         else
         {
            ObjectSetDouble(0, vahLabel, OBJPROP_PRICE, g_currentProfile.vahPrice);
         }
         
         string valLabel = prefix + "VAL_Label";
         if(ObjectFind(0, valLabel) < 0)
         {
            ObjectCreate(0, valLabel, OBJ_TEXT, 0, labelTime, g_currentProfile.valPrice);
            ObjectSetString(0, valLabel, OBJPROP_TEXT, "VAL");
            ObjectSetInteger(0, valLabel, OBJPROP_COLOR, VAL_Color);
         }
         else
         {
            ObjectSetDouble(0, valLabel, OBJPROP_PRICE, g_currentProfile.valPrice);
         }
      }
   }
   
   if(ShowCurrentSession)
   {
      string sessionBox = prefix + "Session_" + IntegerToString((int)g_currentProfile.startTime);
      double chartMax, chartMin;
      if(ChartGetDouble(0, CHART_PRICE_MAX, 0, chartMax) && 
         ChartGetDouble(0, CHART_PRICE_MIN, 0, chartMin))
      {
         if(ObjectFind(0, sessionBox) < 0)
         {
             if(ObjectCreate(0, sessionBox, OBJ_RECTANGLE, 0, g_currentProfile.startTime, chartMax))
            {
               ObjectSetInteger(0, sessionBox, OBJPROP_COLOR, clrGray);
               ObjectSetInteger(0, sessionBox, OBJPROP_FILL, FillCurrentSession);
               ObjectSetInteger(0, sessionBox, OBJPROP_BACK, true);
               ObjectSetDouble(0, sessionBox, OBJPROP_PRICE, chartMax);
               ObjectSetDouble(0, sessionBox, OBJPROP_PRICE, chartMin);
               ObjectSetInteger(0, sessionBox, OBJPROP_TIME, g_currentProfile.endTime);
            }
         }
      }
   }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 2)
      return 0;
   
   datetime currentTime = TimeCurrent();
   static datetime lastBarTime = 0;
   
   datetime barTime = time[rates_total - 1];
   bool isNewBar = (barTime != lastBarTime);
   lastBarTime = barTime;
   
   bool needsRefresh = isNewBar;
   
   if(ProfileMode == MODE_SESSION && !UseCustomSession)
   {
      MqlDateTime dt;
      TimeToStruct(barTime, dt);
      
      if(dt.hour == 0 && isNewBar)
         needsRefresh = true;
   }
   else if(ProfileMode == MODE_FIXED_RANGE && (prev_calculated == 0 || rates_total > prev_calculated))
   {
      needsRefresh = true;
   }
   
   if(needsRefresh)
   {
      ObjectDelete(0, "VP_POC_" + IntegerToString((int)g_currentProfile.startTime));
      ObjectDelete(0, "VP_VAH_" + IntegerToString((int)g_currentProfile.startTime));
      ObjectDelete(0, "VP_VAL_" + IntegerToString((int)g_currentProfile.startTime));
      ObjectDelete(0, "VP_VA_Box_" + IntegerToString((int)g_currentProfile.startTime));
      ObjectDelete(0, "VP_Session_" + IntegerToString((int)g_currentProfile.startTime));
      
      BuildProfile();
      DrawProfile();
   }
   
   for(int i = 0; i < MathMin(rates_total, 10); i++)
   {
      BufferPOC[i] = g_currentProfile.pocPrice;
      BufferVAH[i] = g_currentProfile.vahPrice;
      BufferVAL[i] = g_currentProfile.valPrice;
   }
   
   return rates_total;
}

bool IsNewDay(datetime lastTime, datetime currentTime)
{
   MqlDateTime lastDt, currentDt;
   TimeToStruct(lastTime, lastDt);
   TimeToStruct(currentTime, currentDt);
   return (lastDt.day != currentDt.day || lastDt.mon != currentDt.mon || lastDt.year != currentDt.year);
}

double GetPOCPrice() { return g_currentProfile.pocPrice; }
double GetVAHPrice() { return g_currentProfile.vahPrice; }
double GetVALPrice() { return g_currentProfile.valPrice; }
double GetTotalVolume() { return g_currentProfile.totalVolume; }
datetime GetProfileStartTime() { return g_currentProfile.startTime; }
datetime GetProfileEndTime() { return g_currentProfile.endTime; }

bool IsPriceInValueArea(double price)
{
   return (price > g_currentProfile.valPrice && price < g_currentProfile.vahPrice);
}

double GetDistanceToPOC(double price)
{
   return MathAbs(price - g_currentProfile.pocPrice) / _Point;
}

int GetProfileZone(double price)
{
   if(MathAbs(price - g_currentProfile.pocPrice) < TicksPerRow * _Point * 2)
      return 0; // POC zone
   
   if(price >= g_currentProfile.vahPrice)
      return 1; // Above VAH
   
   if(price <= g_currentProfile.valPrice)
      return 2; // Below VAL
   
   return 3; // Inside VA
}
