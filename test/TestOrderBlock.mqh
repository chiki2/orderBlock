//+------------------------------------------------------------------+
//|                                               TestOrderBlock.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../OBInclude/inputs.mqh"
#include "../OBInclude/globals.mqh"
#include "../OBInclude/helpers.mqh"
#include "../OBInclude/drawOB.mqh"
#include "../OBInclude/types.mqh"

int tests_performed=0;
int tests_passed=0;

#include "TestHelpers.mqh"
#include "TestLangs.mqh"
#include "TestOBStruct.mqh"
#include "TestOrderBlock2.mqh"
#include "TestTypes.mqh"
#include "TestGlobals.mqh"
#include "TestDrawOB.mqh"
#include "TestExportOB.mqh"
#include "TestAltStrat.mqh"
#include "TestSQLite.mqh"
#include "TestDiagnosticPanel.mqh"


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool testFibonacci()
  {

// Retracement
   tests_performed++;
   double res = 0.0;
   // fibo 68% on a bearish ob
   if(68.0 != getFibLevel(true, 100, 0, 0.68))
      return false;
   tests_passed++;
   
   tests_performed++;
   // fibo 68% on a bullish ob
   if(68.0 != getFibLevel(false, 0, 100, 0.68))
      return false;
   tests_passed++;
   
   tests_performed++;
   if(50.0 != getFibLevel(false, 100, 0, 0.50))
      return false;
   tests_passed++;
   
   tests_performed++;
   if(50.0 != getFibLevel(true, 100, 0, 0.50))
      return false;
   tests_passed++;
   
// Extension
   tests_performed++;
   if(127.0 != getFibLevel(false, 100, 0, 1.27))
      return false;
   tests_passed++;
   
   tests_performed++;
   if(127.0 != getFibLevel(true, 0, 100, 1.27))
      return false;
   tests_passed++;
   
   
   return true;
  }
  
bool testRRR(){
   tests_performed++;
   cOrderBlock obTest[];
   ArrayResize(obTest, 1);
   
   // bullish ob 
   obTest[0].entryPrice = getFibLevel(false, 4100, 3990, 0.618);
   obTest[0].stopLoss   = getFibLevel(false, 4100, 3990, -0.35);
   obTest[0].getTPByRRR(1.0);
   
   if ( obTest[0].takeProfit != 4112.54)
      return false;
   tests_passed++;
   
   // bearish ob 
   tests_performed++;
   obTest[0].entryPrice = getFibLevel(true, 4100, 3990, 0.618);
   obTest[0].stopLoss   = getFibLevel(true, 3990, 4100, -0.35);
   obTest[0].getTPByRRR(1.0);
   
   if ( obTest[0].takeProfit != 4164.46 )
      return false;
   tests_passed++;
   
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TestHelpers(const string test_name)
  {
   PrintFormat("%s started",test_name);
//--- test 1
   PrintFormat("%s: Group test 1: Fibonacci",test_name);
   if(!testFibonacci())
      return(false);
   PrintFormat("%s: Group test 2: RRR",test_name);
   if(!testRRR())
      return(false);
         
   return true;
  }

//+------------------------------------------------------------------+
//| TestQueue.                                                       |
//+------------------------------------------------------------------+
void TestQueue()
  {
   string test_name="";
//--- In Helpers.mqh, test fib functions (original tests)
   test_name="Test Fibonacci functions";
   if(TestHelpers(test_name) == false)
      PrintFormat("%s failed",test_name);

//--- Extended helpers tests (TestHelpers.mqh)
   test_name="Test Helpers extended";
   PrintFormat("%s started", test_name);
   if(!RunHelpersTests(test_name))
      PrintFormat("%s failed", test_name);
   else
      PrintFormat("%s passed", test_name);

//--- langs.mqh: T() translation and GetEnumDescription() (TestLangs.mqh)
   test_name="Test Langs";
   PrintFormat("%s started", test_name);
   if(!RunLangsTests(test_name))
      PrintFormat("%s failed", test_name);
   else
      PrintFormat("%s passed", test_name);

//--- OBStruct.mqh: pure struct methods (TestOBStruct.mqh)
    test_name="Test OBStruct";
    PrintFormat("%s started", test_name);
    if(!RunOBStructTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

//--- Additional tests for remaining OBInclude modules
    test_name="Test OrderBlock2";
    PrintFormat("%s started", test_name);
    if(!RunOrderBlock2Tests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

    test_name="Test Types";
    PrintFormat("%s started", test_name);
    if(!RunTypesTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

    test_name="Test Globals";
    PrintFormat("%s started", test_name);
    if(!RunGlobalsTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

    test_name="Test DrawOB";
    PrintFormat("%s started", test_name);
    if(!RunDrawOBTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

    test_name="Test ExportOB";
    PrintFormat("%s started", test_name);
    if(!RunExportOBTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

    test_name="Test AltStrat";
    PrintFormat("%s started", test_name);
    if(!RunAltStratTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

    test_name="Test SQLite";
    PrintFormat("%s started", test_name);
    if(!RunSQLiteTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);

    test_name="Test DiagnosticPanel";
    PrintFormat("%s started", test_name);
    if(!RunDiagnosticPanelTests(test_name))
       PrintFormat("%s failed", test_name);
    else
       PrintFormat("%s passed", test_name);
   }
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void testOrderBlock()
  {
   MathSrand(0);
   string package_name="OrderBlock";
   PrintFormat("Unit tests for Package %s\n",package_name);
//--- test distributions
   TestQueue();
//--- print statistics
   PrintFormat("\n%d of %d passed",tests_passed,tests_performed);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
