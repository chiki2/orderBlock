//+------------------------------------------------------------------+
//|                                                     exportOB.mqh |
//|              OB lifecycle CSV export for Python model training   |
//|                                                                  |
//| Writes one CSV row per OB lifecycle event so that a Python RF   |
//| model can learn which ICT patterns succeed vs fail.             |
//|                                                                  |
//| Included in OrderBlock.mq5 after globals.mqh.                  |
//| Depends on: obBuffer[], rA[], mHTFTrend, CTOB, spread,         |
//|             getAtr(), bidPrice, askPrice                        |
//+------------------------------------------------------------------+
#ifndef EXPORT_OB_MQH
#define EXPORT_OB_MQH

//--- global file handle (INVALID_HANDLE = not open)
int g_exportHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Helper: MarketTrend enum → readable string                      |
//+------------------------------------------------------------------+
string ExportTrendStr(MarketTrend t)
  {
   switch(t)
     {
      case TREND_BULLISH: return "BULLISH";
      case TREND_BEARISH: return "BEARISH";
      case TREND_RANGE:   return "RANGE";
      default:            return "UNKNOWN";
     }
  }

//+------------------------------------------------------------------+
//| Helper: NoTradeReason → readable string (numeric fallback)      |
//+------------------------------------------------------------------+
string ExportReasonStr(NoTradeReason r)
  {
   return IntegerToString((int)r);
  }

//+------------------------------------------------------------------+
//| ExportOBFilename — builds the output filename                   |
//| Pattern: ob_data_{Symbol}_{Period}_{YYYYMMDD}.csv               |
//+------------------------------------------------------------------+
string ExportOBFilename()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return StringFormat("ob_data_%s_%s_%04d%02d%02d.csv",
                       _Symbol,
                       EnumToString(CTOB),
                       dt.year, dt.mon, dt.day);
  }

//+------------------------------------------------------------------+
//| ExportOBHeader — writes the CSV header row                      |
//+------------------------------------------------------------------+
void ExportOBHeader(int handle)
  {
   string header =
      "export_time,event_type,symbol,timeframe,"
      "ob_name,ob_start_time,is_bear,htf_trend,stars,reason,"
      "high_price,low_price,ob_body,ob_wick,"
      "is_mss,is_bos,has_choch,mss_level,"
      "is_imbalanced,imbalanced_dist,imbalance_price,fvg_filled,"
      "lssc_valid,has_sweep_before,"
      "fib50,fib80,fib100,fib127,fib1618,"
      "top_imp_valid,top_imp_level,is_lower_mss,all_checks,final_check,"
      "entry_price,stop_loss,take_profit,lot_size,"
      "c1_open,c1_high,c1_low,c1_close,"
      "c2_open,c2_high,c2_low,c2_close,"
      "atr,spread,bid,ask,"
      "vp_poc_price,vp_vah_price,vp_val_price,"
      "outcome,r_multiple\n";
   FileWriteString(handle, header);
  }

//+------------------------------------------------------------------+
//| ExportOBInit — opens (or creates) the export file               |
//| Call once from OnInit().                                        |
//+------------------------------------------------------------------+
void ExportOBInit()
  {
   string fname = ExportOBFilename();
   bool   isNew = !FileIsExist(fname);

   g_exportHandle = FileOpen(fname,
                             FILE_CSV | FILE_WRITE | FILE_READ | FILE_ANSI | FILE_SHARE_READ,
                             ',');
   if(g_exportHandle == INVALID_HANDLE)
     {
      PrintFormat("[ExportOB] ERROR: cannot open file '%s' (%d)", fname, GetLastError());
      return;
     }

   // Append mode: seek to end; write header only for new files
   FileSeek(g_exportHandle, 0, SEEK_END);
   if(isNew)
      ExportOBHeader(g_exportHandle);

   PrintFormat("[ExportOB] Export file opened: %s", fname);
  }

//+------------------------------------------------------------------+
//| ExportOBClose — flushes and closes the export file              |
//| Call from OnDeinit().                                           |
//+------------------------------------------------------------------+
void ExportOBClose()
  {
   if(g_exportHandle != INVALID_HANDLE)
     {
      FileFlush(g_exportHandle);
      FileClose(g_exportHandle);
      g_exportHandle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| ExportOBEvent — writes one CSV row for OB index i               |
//|                                                                  |
//| event_type : "DETECTED" | "FILTERED_DETECT" | "FILTERED_TICK"  |
//|              "TRADED"   | "CLOSED_WIN"       | "CLOSED_LOSS"    |
//|              "EXPIRED"  | "MITIGATED"                           |
//| outcome    : "WIN" | "LOSS" | "MISS" | "EXPIRED" | "" (empty)  |
//| r_multiple : realized R/R at close (0.0 if not applicable)     |
//+------------------------------------------------------------------+
void ExportOBEvent(const string event_type,
                   int          i,
                   const string outcome    = "",
                   double       r_multiple = 0.0)
  {
   if(g_exportHandle == INVALID_HANDLE)
      return;
   if(i < 0 || i >= ArraySize(obBuffer))
      return;

   //--- snapshot globals at export time
   double cur_atr    = getAtr(14);
   double cur_bid    = bidPrice;
   double cur_ask    = askPrice;

   //--- candle data (rA[1] = previous closed candle, rA[2] = 2 bars ago)
   double c1o = (ArraySize(rA) > 1) ? rA[1].open  : 0;
   double c1h = (ArraySize(rA) > 1) ? rA[1].high  : 0;
   double c1l = (ArraySize(rA) > 1) ? rA[1].low   : 0;
   double c1c = (ArraySize(rA) > 1) ? rA[1].close : 0;
   double c2o = (ArraySize(rA) > 2) ? rA[2].open  : 0;
   double c2h = (ArraySize(rA) > 2) ? rA[2].high  : 0;
   double c2l = (ArraySize(rA) > 2) ? rA[2].low   : 0;
   double c2c = (ArraySize(rA) > 2) ? rA[2].close : 0;

   //--- Volume Profile approximation: D1 VWAP as POC, prev session H/L as VAH/VAL
   double vp_poc = 0, vp_vah = 0, vp_val = 0;
   MqlRates h1rates[];
   if(CopyRates(_Symbol, PERIOD_H1, iBarShift(_Symbol, PERIOD_H1, iTime(_Symbol, PERIOD_D1, 1)), 24, h1rates) == 24)
     {
      double wsum = 0, vsum = 0;
      double dh = -DBL_MAX, dl = DBL_MAX;
      for(int _k = 0; _k < 24; _k++)
        {
         double tp = (h1rates[_k].high + h1rates[_k].low + h1rates[_k].close) / 3.0;
         double v  = (double)h1rates[_k].tick_volume;
         wsum += tp * v;
         vsum += v;
         if(h1rates[_k].high > dh) dh = h1rates[_k].high;
         if(h1rates[_k].low  < dl) dl = h1rates[_k].low;
        }
      vp_poc = (vsum > 0) ? wsum / vsum : 0;
      vp_vah = dh;
      vp_val = dl;
     }

   //--- build CSV row (no commas inside string values)
   string row = StringFormat(
      "%s,%s,%s,%s,"           // export_time, event_type, symbol, timeframe
      "%s,%s,%d,%s,%d,%s,"    // ob_name, ob_start_time, is_bear, htf_trend, stars, reason
      "%.5f,%.5f,%.5f,%.5f,"  // high_price, low_price, ob_body, ob_wick
      "%d,%d,%d,%.5f,"        // is_mss, is_bos, has_choch, mss_level
      "%d,%.5f,%.5f,%d,"      // is_imbalanced, imbalanced_dist, imbalance_price, fvg_filled
      "%d,%d,"                // lssc_valid, has_sweep_before
      "%.5f,%.5f,%.5f,%.5f,%.5f,"  // fib50..fib1618
      "%d,%.5f,%d,%d,%d,"     // top_imp_valid, top_imp_level, is_lower_mss, all_checks, final_check
      "%.5f,%.5f,%.5f,%.5f,"  // entry_price, stop_loss, take_profit, lot_size
      "%.5f,%.5f,%.5f,%.5f,"  // c1 ohlc
      "%.5f,%.5f,%.5f,%.5f,"  // c2 ohlc
      "%.5f,%d,%.5f,%.5f,"    // atr, spread, bid, ask
      "%.5f,%.5f,%.5f,"       // vp_poc_price, vp_vah_price, vp_val_price
      "%s,%.4f\n",            // outcome, r_multiple

      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
      event_type,
      _Symbol,
      EnumToString(CTOB),

      obBuffer[i].name,
      TimeToString(obBuffer[i].startTime, TIME_DATE | TIME_SECONDS),
      (int)obBuffer[i].isBear,
      ExportTrendStr(mHTFTrend),
      obBuffer[i].stars,
      ExportReasonStr(obBuffer[i].reason),

      obBuffer[i].highPrice,
      obBuffer[i].lowPrice,
      obBuffer[i].OBBody,
      obBuffer[i].OBWick,

      (int)obBuffer[i].isMSS,
      (int)obBuffer[i].isBOS,
      (int)obBuffer[i].hasChoch,
      obBuffer[i].MSSLevel,

      (int)obBuffer[i].isImbalanced,
      obBuffer[i].imbalancedDist,
      obBuffer[i].imbalancePrice,
      (int)obBuffer[i].ImbalancedFilled,

      (int)obBuffer[i].lsscValid,
      (int)obBuffer[i].HasSweepBefore,

      obBuffer[i].fib50,
      obBuffer[i].fib80,
      obBuffer[i].fib100,
      obBuffer[i].fib127,
      obBuffer[i].fib1618,

      (int)obBuffer[i].topImpValid,
      obBuffer[i].topImpLevel,
      (int)obBuffer[i].isLowerMss,
      (int)obBuffer[i].allChecks,
      obBuffer[i].finalCheck,

      obBuffer[i].entryPrice,
      obBuffer[i].stopLoss,
      obBuffer[i].takeProfit,
      obBuffer[i].lotSize,

      c1o, c1h, c1l, c1c,
      c2o, c2h, c2l, c2c,

      cur_atr,
      spread,
      cur_bid,
      cur_ask,

      vp_poc, vp_vah, vp_val,

      outcome,
      r_multiple
   );

   FileWriteString(g_exportHandle, row);
  }

//+------------------------------------------------------------------+
//| ExportOBClose_WithOutcome                                        |
//|                                                                  |
//| Call from cleanOBBuffer() to determine and write the final      |
//| outcome. Checks trade history for profit/loss.                  |
//+------------------------------------------------------------------+
void ExportOBCloseWithOutcome(int i)
  {
   if(i < 0 || i >= ArraySize(obBuffer))
      return;

   ulong ticket = obBuffer[i].tradeTicket;

   // WIN/LOSS trades are exported in OnTradeTransaction (where profit is
   // directly available from the deal).  Only emit EXPIRED / MISS here.
   if(obBuffer[i].reason == ENUM_REASON_IS_OVERDUE)
     {
      ExportOBEvent("CLOSED", i, "EXPIRED", 0.0);
     }
   else if(ticket == 0 || ticket == ULONG_MAX)
     {
      // No trade was taken — filtered / mitigated without entry
      ExportOBEvent("CLOSED", i, "MISS", 0.0);
     }
   // else: CLOSED with WIN/LOSS already written by OnTradeTransaction hook
  }


//+------------------------------------------------------------------+
//| MTF Candle Context Export — separate CSV for multi-TF analysis    |
//|                                                                  |
//| Writes 3 candles x 5 timeframes at ENTRY and EXIT time.         |
//| File: ob_candles_{Symbol}_{Period}_{YYYYMMDD}.csv                |
//+------------------------------------------------------------------+
int g_candleHandle = INVALID_HANDLE;

string ExportCandleFilename()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return StringFormat("ob_candles_%s_%s_%04d%02d%02d.csv",
                       _Symbol, EnumToString(CTOB),
                       dt.year, dt.mon, dt.day);
  }

void ExportCandleHeader(int handle)
  {
   string header =
      "ob_name,phase,outcome,"
      "tf,tf_minutes,"
      "c1_time,c1_open,c1_high,c1_low,c1_close,c1_body,c1_upper_wick,c1_lower_wick,c1_range,c1_bullish,"
      "c2_time,c2_open,c2_high,c2_low,c2_close,c2_body,c2_upper_wick,c2_lower_wick,c2_range,c2_bullish,"
      "c3_time,c3_open,c3_high,c3_low,c3_close,c3_body,c3_upper_wick,c3_lower_wick,c3_range,c3_bullish\n";
   FileWriteString(handle, header);
  }

void ExportCandleInit()
  {
   string fname = ExportCandleFilename();
   bool   isNew = !FileIsExist(fname);

   g_candleHandle = FileOpen(fname,
                             FILE_CSV | FILE_WRITE | FILE_READ | FILE_ANSI | FILE_SHARE_READ,
                             ',');
   if(g_candleHandle == INVALID_HANDLE)
     {
      PrintFormat("[ExportCandle] ERROR: cannot open '%s' (%d)", fname, GetLastError());
      return;
     }
   FileSeek(g_candleHandle, 0, SEEK_END);
   if(isNew)
      ExportCandleHeader(g_candleHandle);
  }

void ExportCandleClose()
  {
   if(g_candleHandle != INVALID_HANDLE)
     {
      FileFlush(g_candleHandle);
      FileClose(g_candleHandle);
      g_candleHandle = INVALID_HANDLE;
     }
  }

void ExportCandleRow(const string ob_name, const string phase, const string outcome,
                     ENUM_TIMEFRAMES tf, MqlRates &rates[])
  {
   if(g_candleHandle == INVALID_HANDLE) return;
   if(ArraySize(rates) < 4) return;

   int tf_min = PeriodSeconds(tf) / 60;

   string row = "";
   for(int c = 0; c < 3; c++)
     {
      int idx = c + 1;
      if(idx >= ArraySize(rates)) break;
      double o = rates[idx].open;
      double h = rates[idx].high;
      double l = rates[idx].low;
      double cl = rates[idx].close;
      double body = MathAbs(cl - o);
      double range_val = h - l;
      double upper_wick = h - MathMax(o, cl);
      double lower_wick = MathMin(o, cl) - l;
      int bullish = (cl >= o) ? 1 : 0;

      if(c > 0) row += ",";
      row += StringFormat("%s,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%d",
                          TimeToString(rates[idx].time, TIME_DATE | TIME_SECONDS),
                          o, h, l, cl, body, upper_wick, lower_wick, range_val, bullish);
     }

   string prefix = StringFormat("%s,%s,%s,%s,%d,",
                                ob_name, phase, outcome,
                                EnumToString(tf), tf_min);
   FileWriteString(g_candleHandle, prefix + row + "\n");
  }

void ExportCandleContext(int i, const string phase, const string outcome = "")
  {
   if(g_candleHandle == INVALID_HANDLE) return;
   if(i < 0 || i >= ArraySize(obBuffer)) return;

   ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
   MqlRates buf[5];
   string ob_name = obBuffer[i].name;

   for(int t = 0; t < ArraySize(tfs); t++)
     {
      if(CopyRates(_Symbol, tfs[t], 0, 5, buf) >= 4)
         ExportCandleRow(ob_name, phase, outcome, tfs[t], buf);
     }
  }

#endif  // EXPORT_OB_MQH
