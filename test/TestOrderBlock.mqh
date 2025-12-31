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
   if(0.68 != getFibLevel(false, 100, 0, 0.68))
      return false;
   tests_passed++;
   tests_performed++;
   if(0.68 != getFibLevel(true, 100, 0, 0.68))
      return false;
   tests_passed++;
   tests_performed++;
   if(0.50 != getFibLevel(false, 100, 0, 0.50))
      return false;
   tests_passed++;
   tests_performed++;
   if(0.50 != getFibLevel(true, 100, 0, 0.50))
      return false;
   tests_passed++;

// Extension
   tests_performed++;
   if(1.27 != getFibLevel(false, 100, 0, 1.27))
      return false;
   tests_passed++;
   tests_performed++;
   if(1.27 != getFibLevel(true, 100, 0, 1.27))
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
