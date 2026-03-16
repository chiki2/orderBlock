//+------------------------------------------------------------------+
//|                                              TestGlobals.mqh   |
//|              Unit tests for OBInclude/globals.mqh               |
//+------------------------------------------------------------------+
#ifndef TEST_GLOBALS_MQH
#define TEST_GLOBALS_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/globals.mqh"

bool testGlobalConstants()
  {
    ASSERT_INT(HTOB, 16385, "HTOB: PERIOD_H1 == 16385");
    ASSERT_INT(CTOB, 15, "CTOB: PERIOD_M15 == 15");
    ASSERT_INT(typeofOrder, 1, "typeofOrder: LIMIT == 1");
    ASSERT_INT(INVALID_TICKET, -1, "INVALID_TICKET == -1");
    
    return true;
  }

bool testArraySentinels()
  {
    orderBlock obBufferTest[];
    ArrayResize(obBufferTest, 1);
    
    ASSERT_INT(ArraySize(obBufferTest), 1, "obBuffer: default resize works");
    ASSERT_INT(obBufferTest[0].stars, 0, "obBuffer[0]: stars sentinel == 0");
    ASSERT_BOOL(obBufferTest[0].isDone, false, "obBuffer[0]: isDone sentinel == false");
    
    return true;
  }

bool RunGlobalsTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] Global constants", suite);
    if(!testGlobalConstants())
      { PrintFormat("  FAILED: Global constants"); all_ok = false; }
    
    PrintFormat("  [%s] Array sentinels", suite);
    if(!testArraySentinels())
      { PrintFormat("  FAILED: Array sentinels"); all_ok = false; }
    
    return all_ok;
  }

#endif
