//+------------------------------------------------------------------+
//|                                               TestOrderBlock.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "../OBInclude/inputs.mqh"
#include "../OBInclude/globals.mqh"
#include "../OBInclude/helpers.mqh"
#include "../OBInclude/drawOB.mqh"
#include "../OBInclude/OBStruct.mqh"

int tests_performed=0;
int tests_passed=0;


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
   orderBlock obTest[];
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
//--- In Helpers.mqh, test fib functions
   test_name="Test Fibonacci functions";
   if(TestHelpers(test_name) == false)
      PrintFormat("%s failed",test_name);
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
