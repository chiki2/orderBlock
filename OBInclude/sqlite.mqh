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
   int db = DatabaseOpen(filename, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | FILE_COMMON);
   
   if(DatabaseTableExists(db, "OrderBlock") == false)
     {
      if(!DatabaseExecute(db, "CREATE TABLE OrderBlock("
                          "ID          INTEGER PRIMARY KEY,"
                          "NAME        TEXT    NOT NULL,"
                          "startime    LONG    NOT NULL UNIQUE,"
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
                          "stoplossDistance REAL"
                          ");"))
        {
         Print("DB: ", filename, " create table failed with code ", _LastError);
         DatabaseClose(db);
        }
     }

   if(DatabaseTableExists(db, "history") == false)
     {
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
        }
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
   int db = DatabaseOpen(filename, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE| FILE_COMMON);

   string Query = "INSERT INTO OrderBlock "
                  "(NAME,startime,entryPrice,entryTime, highPrice, lowPrice,"
                  "imbalancePrice,isMitigated,isBOS, DoTrailing, HasSweepBefore,"
                  "mitigatedTime,mitigatedLine,isImbalanced, ImbalancedFilled, imbalancedDist,"
                  "isBear,stars,isDone, OBBody, OBWick,fibn027,fib50,fib80,fib100,fib140,fib127,"
                  "fib1618,fib200,fib23812, fibLimit, prevlowi,prevhighi,cross127,cross161,"
                  "cross238,cross50,tradeTicket, takeProfit,stopLoss)"
                  "VALUES ('" + obBuffer[i].name + "',"
                  + IntegerToString(obBuffer[i].startTime) + ","
                  + DoubleToString(obBuffer[i].entryPrice,2) + ","
                  + IntegerToString(obBuffer[i].entryTime) + ","
                  + DoubleToString(obBuffer[i].highPrice) + ","
                  + DoubleToString(obBuffer[i].lowPrice) + ","
                  + DoubleToString(obBuffer[i].imbalancePrice) + ","
                  + ((obBuffer[i].isMitigated == true) ? "true" : "false") + ","
                  + ((obBuffer[i].isBOS == true) ? "true" : "false") + ","
                  + ((obBuffer[i].DoTrailing == true) ? "true" : "false") + ","
                  + ((obBuffer[i].HasSweepBefore == true) ? "true" : "false") + ","
                  + IntegerToString(obBuffer[i].mitigatedTime) + ","
                  + DoubleToString(obBuffer[i].mitigatedLine) + ","
                  + ((obBuffer[i].isImbalanced == true) ? "true" : "false") + ","
                  + ((obBuffer[i].ImbalancedFilled == true) ? "true" : "false") + ","
                  + DoubleToString(obBuffer[i].imbalancedDist) + ","
                  + ((obBuffer[i].isBear == true) ? "true" : "false") + ","
                  + IntegerToString(obBuffer[i].stars) + ","
                  + ((obBuffer[i].isDone == true) ? "true" : "false") + ","
                  + DoubleToString(obBuffer[i].OBBody) + ","
                  + DoubleToString(obBuffer[i].OBWick) + ","
                  + DoubleToString(obBuffer[i].fibn027) + ","
                  + DoubleToString(obBuffer[i].fib50)+ ","
                  + DoubleToString(obBuffer[i].fib80) + ","
                  + DoubleToString(obBuffer[i].fib100) + ","
                  + DoubleToString(obBuffer[i].fib140) + ","
                  + DoubleToString(obBuffer[i].fib127) + ","
                  + DoubleToString(obBuffer[i].fib1618) + ","
                  + DoubleToString(obBuffer[i].fib200) + ","
                  + DoubleToString(obBuffer[i].fib23812) + ","
                  + DoubleToString(obBuffer[i].fibLimit) + ","
                  + IntegerToString(obBuffer[i].prevlowi) + ","
                  + IntegerToString(obBuffer[i].prevhighi) + ","
                  + ((obBuffer[i].cross127 == true) ? "true" : "false") + ","
                  + ((obBuffer[i].cross161 == true) ? "true" : "false") + ","
                  + ((obBuffer[i].cross238 == true) ? "true" : "false") + ","
                  + ((obBuffer[i].cross50 == true) ? "true" : "false") + ","
                  + IntegerToString(obBuffer[i].tradeTicket) + ","
                  + DoubleToString(obBuffer[i].takeProfit) + ","
                  + DoubleToString(obBuffer[i].stopLoss)
                  + "); ";
   if(DatabaseExecute(db,Query) == false)
     {
      Print("DB: ", filename, " insert failed with code ", GetLastError());
      DatabaseClose(db);
      return 0;
     }
   else
     {
      Print("insert ok");
     }
   return 1;
  }

//+------------------------------------------------------------------+
