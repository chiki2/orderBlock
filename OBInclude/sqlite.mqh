//+------------------------------------------------------------------+
//|                                                       sqlite.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#include "OBStruct.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MqlLite
  {
private:

public:
   string            filename;
                     MqlLite(void);
                    ~MqlLite(void);
   bool              createDB();
   bool              destroyDB();
   int               insertOB(int i);
   int               insertTrade();
   bool              updateOB();
   bool              updateTrade();
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void              MqlLite::MqlLite(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void              MqlLite::~MqlLite(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool              MqlLite::createDB(void)
  {
   filename = "GoldICTOrderBlock.db";
   int db = DatabaseOpen(filename, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
   if(!DatabaseExecute(db, "CREATE TABLE OrderBlock("
                       "ID          INTEGER PRIMARY KEY,"
                       "NAME        TEXT    NOT NULL,"
                       "startime    LONG    NOT NULL,"
                       "entryPrice  REAL,"
                       "entryTime   LONG    NOT NULL,"
                       "highPrice   REAL,"
                       "lowPrice    REAL,"
                       "imbalancePrice REAL,"
                       "isMitigated BOOL,"
                       "isBOS       BOOL,"
                       "DoTrailing  BOOL,"
                       "HasSweepBefore BOOL,"
                       "mitigatedTime LONG,"
                       "mitigatedLine REAL,"
                       "isImbalanced BOOL,"
                       "ImbalancedFilled BOOL,"
                       "imbalancedDist REAL,"
                       "isBear      BOOL,"
                       "stars       SHORT,"
                       "isDone      BOOL,"
                       "OBBody      REAL,"
                       "OBWick      REAL,"
                       "fibn027     REAL,"
                       "fib50       REAL,"
                       "fib80       REAL,"
                       "fib100      REAL,"
                       "fib140      REAL,"
                       "fib127      REAL,"
                       "fib1618     REAL,"
                       "fib200      REAL,"
                       "fib23812    REAL,"
                       "fibLimit    REAL,"
                       "prevlowi    LONG,"
                       "prevhighi   LONG,"
                       "cross127    BOOL,"
                       "cross161    BOOL,"
                       "cross238    BOOL,"
                       "cross50     BOOL,"
                       "tradeTicket LONG,"
                       "takeProfit  REAL,"
                       "stoploss    REAL,"
                       "stoplossDistance REAL);"))
     {
      Print("DB: ", filename, " create table failed with code ", _LastError);
      DatabaseClose(db);
      return false;
     }

   if(!DatabaseExecute(db, "CREATE TABLE history("
                       "ID          INT     PRIMARY KEY NOT NULL,"
                       "entryPrice  REAL,"
                       "entryTime   INT    NOT NULL,"
                       "tradeTicket LONG,"
                       "takeProfit  REAL,"
                       "stoploss    REAL,"
                       "is1R        BOOL);"))
     {
      Print("DB: ", filename, " create table failed with code ", _LastError);
      DatabaseClose(db);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int            MqlLite::insertOB(int i)
  {
   if(i > ArraySize(obBuffer))
     {
      return 0;
     }
   int db = DatabaseOpen(filename, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
   
   string Query = "INSERT INTO OrderBlock "
                  "(NAME,startime,entryPrice,entryTime, highPrice, lowPrice,"
                  "imbalancePrice,isMitigated,isBOS, DoTrailing, HasSweepBefore,"
                  "mitigatedTime,mitigatedLine,isImbalanced, ImbalancedFilled, imbalancedDist,"
                  "isBear,stars,isDone, OBBody, OBWick,fibn027,fib50,fib80,fib100,fib140,fib127,"
                  "fib1618,fib200,fib23812, fibLimit, prevlowi,prevhighi,cross127,cross161,"
                  "cross238,cross50,tradeTicket, takeProfit,stopLoss)"
                  "VALUES ('" + obBuffer[i].name + "',"
                  + (long)obBuffer[i].startTime + ","
                  + DoubleToString(obBuffer[i].entryPrice,2) + ","
                  + (long)obBuffer[i].entryTime + ","
                  + obBuffer[i].highPrice + ","
                  + obBuffer[i].lowPrice + ","
                  + obBuffer[i].imbalancePrice + ","
                  + obBuffer[i].isMitigated + ","
                  + obBuffer[i].isBOS + ","
                  + obBuffer[i].DoTrailing + ","
                  + obBuffer[i].HasSweepBefore + ","
                  + (long)obBuffer[i].mitigatedTime + ","
                  + obBuffer[i].mitigatedLine + ","
                  + obBuffer[i].isImbalanced + ","
                  + obBuffer[i].ImbalancedFilled + ","
                  + obBuffer[i].imbalancedDist + ","
                  + obBuffer[i].isBear + ","
                  + obBuffer[i].stars + ","
                  + obBuffer[i].isDone+ ","
                  + obBuffer[i].OBBody + ","
                  + obBuffer[i].OBWick + ","
                  + obBuffer[i].fibn027 + ","
                  + obBuffer[i].fib50+ ","
                  + obBuffer[i].fib80 + ","
                  + obBuffer[i].fib100 + ","
                  + obBuffer[i].fib140 + ","
                  + obBuffer[i].fib127 + ","
                  + obBuffer[i].fib1618 + ","
                  + obBuffer[i].fib200 + ","
                  + obBuffer[i].fib23812 + ","
                  + obBuffer[i].fibLimit + ","
                  + (long) obBuffer[i].prevlowi + ","
                  + (long) obBuffer[i].prevhighi + ","
                  + obBuffer[i].cross127 + ","
                  + obBuffer[i].cross161 + ","
                  + obBuffer[i].cross238 + ","
                  + obBuffer[i].cross50 + ","
                  + obBuffer[i].tradeTicket + ","
                  + obBuffer[i].takeProfit + ","
                  + obBuffer[i].stopLoss
                  + "); ";
   if(!DatabaseExecute(db,Query))
     {
      Print("DB: ", filename, " insert failed with code ", _LastError);
      DatabaseClose(db);
      return 0;
     }else{
      Print("insert ok");
     
     }


   return 1;
  }

//+------------------------------------------------------------------+
