//+------------------------------------------------------------------+
//|                                               TestOBStruct.mqh  |
//|            Unit tests for OBInclude/OBStruct.mqh               |
//|                                                                  |
//| Covers the pure / side-effect-free methods of the orderBlock    |
//| struct that do not call market APIs (iBarShift, open, etc.).    |
//|                                                                  |
//| Intentionally NOT tested (require live market data):            |
//|   - init(), hasOppositeOB(), checkForMSSEntry()                 |
//|   - checkForMSSBefore(), checkForCrossLiquidity()               |
//|   - hasCounterChoch(), getMaxImpulsion(), GetCurrentRR()        |
//|   - getAutoEntryType() branches 1 & 2 (call open/iBarShift)    |
//+------------------------------------------------------------------+
#ifndef TEST_OBSTRUCT_MQH
#define TEST_OBSTRUCT_MQH

// Re-use assertion macros from TestHelpers.mqh (included before this file)

//+------------------------------------------------------------------+
//| addStars() — simple accumulator, pure arithmetic                 |
//+------------------------------------------------------------------+
bool testAddStars()
  {
   cOrderBlock ob;

// Default parameter: adds 1
   ob.stars = 0;
   ob.addStars();
   ASSERT_INT(ob.stars, 1, "addStars: default adds 1");

// Explicit positive
   ob.stars = 0;
   ob.addStars(5);
   ASSERT_INT(ob.stars, 5, "addStars: +5 from 0");

// Cumulative
   ob.stars = 3;
   ob.addStars(2);
   ASSERT_INT(ob.stars, 5, "addStars: 3 + 2 == 5");

// Add 0 is a no-op
   ob.stars = 7;
   ob.addStars(0);
   ASSERT_INT(ob.stars, 7, "addStars: +0 is no-op");

// Negative decrement
   ob.stars = 10;
   ob.addStars(-3);
   ASSERT_INT(ob.stars, 7, "addStars: -3 decrements");

// Large values
   ob.stars = 0;
   ob.addStars(1000);
   ASSERT_INT(ob.stars, 1000, "addStars: large value");

   return true;
  }


//+------------------------------------------------------------------+
//| getAutoEntryType() — FVG branch (pure path)                     |
//|                                                                  |
//| The function has three branches determined by                   |
//|   imbalancedDist vs obSize * threshold:                         |
//|                                                                  |
//|   imbalancedDist < obSize * 0.25  -> ENUM_ENTRY_OBOPEN (impure) |
//|   imbalancedDist < obSize * 0.75  -> ENUM_ENTRY_F50    (impure) |
//|   imbalancedDist >= obSize * 0.75 -> ENUM_ENTRY_FVG    (pure)   |
//|                                                                  |
//| Only the FVG branch is tested here because branches 1 & 2 call  |
//| open(iBarShift(...)) which requires live market data.           |
//|                                                                  |
//| FVG branch side-effects (pure):                                 |
//|   fib50       = imbalancePrice                                  |
//|   entryPrice  = imbalancePrice                                  |
//+------------------------------------------------------------------+
bool testGetAutoEntryTypeFVG()
  {
   cOrderBlock ob;

//--- Scenario 1: large imbalancedDist clearly above 75 % threshold
// obSize = |200 - 100| = 100,  threshold = 75
// imbalancedDist = 80  ->  80 >= 75  -> FVG
   ob.OBBody         = 200.0;
   ob.OBWick         = 100.0;
   ob.imbalancedDist = 80.0;
   ob.imbalancePrice = 150.0;

   ASSERT_INT(ob.getAutoEntryType(), ENUM_ENTRY_FVG, "FVG: dist=80 >= 75%% of obSize=100");
   ASSERT_DBL(ob.entryPrice, 150.0, "FVG: entryPrice == imbalancePrice after call");
   ASSERT_DBL(ob.fib50,      150.0, "FVG: fib50 == imbalancePrice after call");

//--- Scenario 2: exactly at the 75 % boundary (not strictly less → FVG)
// obSize = 100,  threshold = 75.0,  imbalancedDist = 75.0
// 75 < 75 is false  -> FVG
   ob.OBBody         = 200.0;
   ob.OBWick         = 100.0;
   ob.imbalancedDist = 75.0;
   ob.imbalancePrice = 160.0;

   ASSERT_INT(ob.getAutoEntryType(), ENUM_ENTRY_FVG, "FVG: dist==75 == 75%% boundary");
   ASSERT_DBL(ob.entryPrice, 160.0, "FVG boundary: entryPrice set");
   ASSERT_DBL(ob.fib50,      160.0, "FVG boundary: fib50 set");

//--- Scenario 3: larger obSize, proportional imbalancedDist
// obSize = 1000, threshold = 750, imbalancedDist = 800
   ob.OBBody         = 1000.0;
   ob.OBWick         = 0.0;
   ob.imbalancedDist = 800.0;
   ob.imbalancePrice = 500.0;

   ASSERT_INT(ob.getAutoEntryType(), ENUM_ENTRY_FVG, "FVG: dist=800 >= 75%% of obSize=1000");
   ASSERT_DBL(ob.entryPrice, 500.0, "FVG large obSize: entryPrice");
   ASSERT_DBL(ob.fib50,      500.0, "FVG large obSize: fib50");

//--- Scenario 4: bearish OB (OBBody < OBWick, obSize computed via MathAbs)
// obSize = |100 - 200| = 100, threshold = 75
// imbalancedDist = 90 >= 75 -> FVG
   ob.OBBody         = 100.0;  // body below wick for bearish
   ob.OBWick         = 200.0;
   ob.imbalancedDist = 90.0;
   ob.imbalancePrice = 140.0;
   ob.isBear         = true;

   ASSERT_INT(ob.getAutoEntryType(), ENUM_ENTRY_FVG, "FVG: bearish obSize via MathAbs");
   ASSERT_DBL(ob.entryPrice, 140.0, "FVG bearish: entryPrice");

   return true;
  }


//+------------------------------------------------------------------+
//| entryType enum — sanity check on defined values                  |
//|                                                                  |
//| Verifies the enum ordinal order matches the expected contract    |
//| so any future reordering is caught immediately.                  |
//+------------------------------------------------------------------+
bool testEntryTypeEnum()
  {
// The enum is defined as:
//   ENUM_ENTRY_FVG   = 0
//   ENUM_ENTRY_F50   = 1
//   ENUM_ENTRY_OBOPEN = 2
   ASSERT_INT((int)ENUM_ENTRY_FVG,    0, "entryType: ENUM_ENTRY_FVG == 0");
   ASSERT_INT((int)ENUM_ENTRY_F50,    1, "entryType: ENUM_ENTRY_F50 == 1");
   ASSERT_INT((int)ENUM_ENTRY_OBOPEN, 2, "entryType: ENUM_ENTRY_OBOPEN == 2");
   return true;
  }


//+------------------------------------------------------------------+
//| MarketTrend enum — sanity check                                  |
//+------------------------------------------------------------------+
bool testMarketTrendEnum()
  {
   ASSERT_INT((int)TREND_RANGE,     0,   "MarketTrend: RANGE == 0");
   ASSERT_INT((int)TREND_BULLISH,   1,   "MarketTrend: BULLISH == 1");
   ASSERT_INT((int)TREND_BEARISH,  -1,   "MarketTrend: BEARISH == -1");
   ASSERT_INT((int)TREND_UKNOWN,  -42,   "MarketTrend: UNKNOWN == -42");
   return true;
  }


//+------------------------------------------------------------------+
//| orderBlock field defaults after ArrayResize                      |
//|                                                                  |
//| MQL5 zero-initialises struct arrays; verify key numeric fields   |
//| that the production code relies on as sentinels.                 |
//+------------------------------------------------------------------+
bool testOBDefaultValues()
  {
   cOrderBlock ob[];
   ArrayResize(ob, 1);

// Numeric sentinels set by init() — before init() they are 0 (zero-init)
   ASSERT_INT(ob[0].stars,      0, "default: stars == 0");
   ASSERT_BOOL(ob[0].isBear,    false, "default: isBear == false");
   ASSERT_BOOL(ob[0].isDone,    false, "default: isDone == false");
   ASSERT_BOOL(ob[0].isMitigated, false, "default: isMitiated == false");
   ASSERT_BOOL(ob[0].hasChoch,  false, "default: hasChoch == false");
   ASSERT_BOOL(ob[0].isBOS,     false, "default: isBOS == false");

// Scalar numerics zero-initialised
   ASSERT_DBL(ob[0].highPrice, 0.0, "default: highPrice == 0");
   ASSERT_DBL(ob[0].lowPrice,  0.0, "default: lowPrice == 0");
   ASSERT_DBL(ob[0].OBBody,    0.0, "default: OBBody == 0");
   ASSERT_DBL(ob[0].OBWick,    0.0, "default: OBWick == 0");

   return true;
  }


//+------------------------------------------------------------------+
//| RunOBStructTests — entry point called by TestOrderBlock         |
//+------------------------------------------------------------------+
bool RunOBStructTests(const string suite)
  {
   bool all_ok = true;

   PrintFormat("  [%s] addStars()", suite);
   if(!testAddStars())
     { PrintFormat("  FAILED: addStars"); all_ok = false; }

   PrintFormat("  [%s] getAutoEntryType() FVG branch", suite);
   if(!testGetAutoEntryTypeFVG())
     { PrintFormat("  FAILED: getAutoEntryType FVG"); all_ok = false; }

   PrintFormat("  [%s] entryType enum ordinals", suite);
   if(!testEntryTypeEnum())
     { PrintFormat("  FAILED: entryType enum"); all_ok = false; }

   PrintFormat("  [%s] MarketTrend enum ordinals", suite);
   if(!testMarketTrendEnum())
     { PrintFormat("  FAILED: MarketTrend enum"); all_ok = false; }

   PrintFormat("  [%s] orderBlock default field values", suite);
   if(!testOBDefaultValues())
     { PrintFormat("  FAILED: OB default values"); all_ok = false; }

   return all_ok;
  }

#endif // TEST_OBSTRUCT_MQH
