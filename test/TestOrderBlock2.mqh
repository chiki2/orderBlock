//+------------------------------------------------------------------+
//|                                            TestOrderBlock2.mqh  |
//|              Unit tests for remaining cOrderBlock functions     |
//+------------------------------------------------------------------+
#ifndef TEST_ORDERBLOCK2_MQH
#define TEST_ORDERBLOCK2_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/types.mqh"
#include "../OBInclude/globals.mqh"
#include "../OBInclude/cOrderBlock.mqh"

bool testIsIndexValid()
  {
    orderBlock arr[];
    cOrderBlock ob;
    ArrayResize(arr, 5);
    
    ASSERT_BOOL(ob.IsIndexValid(0, arr), true, "IsIndexValid: index 0 valid");
    ASSERT_BOOL(ob.IsIndexValid(4, arr), true, "IsIndexValid: index 4 valid");
    ASSERT_BOOL(ob.IsIndexValid(-1, arr), false, "IsIndexValid: negative invalid");
    ASSERT_BOOL(ob.IsIndexValid(5, arr), false, "IsIndexValid: out of bounds");
    ASSERT_BOOL(ob.IsIndexValid(10, arr), false, "IsIndexValid: far out of bounds");
    
    return true;
  }

bool testTrashme()
  {
    cOrderBlock ob;
    ob.trashme(ENUM_REASON_ISMITIGATED);
    
    ASSERT_BOOL(ob.isDone, true, "trashme: isDone set to true");
    ASSERT_INT(ob.stars, 0, "trashme: stars set to 0");
    ASSERT_INT((int)ob.reason, (int)ENUM_REASON_ISMITIGATED, "trashme: reason set correctly");
    
    ob.trashme(ENUM_REASON_NO_MSS);
    ASSERT_INT((int)ob.reason, (int)ENUM_REASON_NO_MSS, "trashme: reason can be overwritten");
    
    return true;
  }

bool testGetTPEdgeCases()
  {
    cOrderBlock ob;
    
    ob.entryPrice = 4000.0;
    ob.stopLoss   = 4000.0;
    ob.isBear     = false;
    ASSERT_BOOL(ob.getTPByRRR(2.0), false, "getTPByRRR: zero risk returns false");
    
    ob.entryPrice = -1.0;
    ob.isBear     = false;
    ASSERT_BOOL(ob.getTPByChange(1.0), false, "getTPByChange: guard entryPrice=-1");
    
    ob.entryPrice = 5000.0;
    ob.isBear     = false;
    ob.getTPByChange(0.0);
    ASSERT_DBL(ob.takeProfit, 5000.0, "getTPByChange: 0% returns entry");
    
    ob.entryPrice = 1000.0;
    ob.isBear     = true;
    ob.getTPByChange(100.0);
    ASSERT_DBL(ob.takeProfit, 0.0, "getTPByChange: bear 100% returns 0");
    
    return true;
  }

bool RunOrderBlock2Tests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] IsIndexValid()", suite);
    if(!testIsIndexValid())
      { PrintFormat("  FAILED: IsIndexValid"); all_ok = false; }
    
    PrintFormat("  [%s] trashme()", suite);
    if(!testTrashme())
      { PrintFormat("  FAILED: trashme"); all_ok = false; }
    
    PrintFormat("  [%s] getTP edge cases", suite);
    if(!testGetTPEdgeCases())
      { PrintFormat("  FAILED: getTP edge cases"); all_ok = false; }
    
    return all_ok;
  }

#endif
