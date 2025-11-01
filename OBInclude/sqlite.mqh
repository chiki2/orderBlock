//+------------------------------------------------------------------+
//|                                                       sqlite.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

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
   int               insertOB();
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
                       "ID          INT     PRIMARY KEY NOT NULL,"
                       "NAME        TEXT    NOT NULL,"
                       "startime    TEXT    NOT NULL,"
                       "entryPrice  REAL,"
                       "entryTime   TEXT    NOT NULL,"
                       "highPrice   REAL,"
                       "lowPrice    REAL,"
                       "imbalancePrice REAL,"
                       "isMitigated BOOL,"
                       "isBOS       BOOL,"
                       "DoTrailing  BOOL,"
                       "HasSweepBefore BOOL,"
                       "mitigatedTime TEXT,"
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
                       "prevlowi    TEXT,"
                       "prevhighi   TEXT,"
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
                       "entryTime   TEXT    NOT NULL,"
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
