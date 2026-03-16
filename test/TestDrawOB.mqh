//+------------------------------------------------------------------+
//|                                              TestDrawOB.mqh     |
//|              Unit tests for OBInclude/drawOB.mqh               |
//+------------------------------------------------------------------+
#ifndef TEST_DRAWOB_MQH
#define TEST_DRAWOB_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/drawOB.mqh"

bool testDrawConstants()
  {
    ASSERT_INT(ARROW_SIZE_DEFAULT, 3, "ARROW_SIZE_DEFAULT == 3");
    ASSERT_INT(LINE_WIDTH_DEFAULT, 1, "LINE_WIDTH_DEFAULT == 1");
    ASSERT_INT(ZORDER_DEFAULT, 0, "ZORDER_DEFAULT == 0");
    
    return true;
  }

bool testColorConstants()
  {
    ASSERT_INT(clrOBBull, 32768, "clrOBBull: clrBlue == 32768");
    ASSERT_INT(clrOBBear, 16711680, "clrOBBear: clrRed == 16711680");
    ASSERT_INT(clrGray, 8421504, "clrGray: == 8421504");
    ASSERT_INT(clrGreen, 65280, "clrGreen: == 65280");
    
    return true;
  }

bool RunDrawOBTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] Draw constants", suite);
    if(!testDrawConstants())
      { PrintFormat("  FAILED: Draw constants"); all_ok = false; }
    
    PrintFormat("  [%s] Color constants", suite);
    if(!testColorConstants())
      { PrintFormat("  FAILED: Color constants"); all_ok = false; }
    
    return all_ok;
  }

#endif
