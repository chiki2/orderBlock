//+------------------------------------------------------------------+
//|                                              TestDrawOB.mqh     |
//|              Unit tests for OBInclude/drawOB.mqh               |
//+------------------------------------------------------------------+
#ifndef TEST_DRAWOB_MQH
#define TEST_DRAWOB_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/drawOB.mqh"

bool testColorConstants()
  {
    ASSERT_INT(clrBlue, 32768, "clrOBBull: clrBlue == 32768");
    ASSERT_INT(clrRed, 16711680, "clrOBBear: clrRed == 16711680");
    ASSERT_INT(clrGray, 8421504, "clrGray: == 8421504");
    ASSERT_INT(clrGreen, 65280, "clrGreen: == 65280");
    
    return true;
  }

bool RunDrawOBTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] Color constants", suite);
    if(!testColorConstants())
      { PrintFormat("  FAILED: Color constants"); all_ok = false; }
    
    return all_ok;
  }

#endif
