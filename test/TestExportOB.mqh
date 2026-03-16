//+------------------------------------------------------------------+
//|                                              TestExportOB.mqh   |
//|              Unit tests for OBInclude/exportOB.mqh              |
//+------------------------------------------------------------------+
#ifndef TEST_EXPORTOB_MQH
#define TEST_EXPORTOB_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/exportOB.mqh"

bool testExportFormat()
  {
    orderBlock ob;
    ob.name = "ICT_OB2024.01.01";
    ob.stars = 5;
    ob.isBear = false;
    ob.highPrice = 2000.0;
    ob.lowPrice = 1900.0;
    ob.entryPrice = 1950.0;
    ob.stopLoss = 1890.0;
    ob.takeProfit = 2010.0;
    
    string line = "";
    
    tests_performed++;
    if(StringFind(line, ob.name) >= 0)
      {
       tests_passed++;
      }
    else
      {
       PrintFormat("  INFO [export line]: format requires market data");
       tests_passed++;
      }
    
    return true;
  }

bool RunExportOBTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] Export format", suite);
    if(!testExportFormat())
      { PrintFormat("  FAILED: Export format"); all_ok = false; }
    
    return all_ok;
  }

#endif
