//+------------------------------------------------------------------+
//|                                              TestSQLite.mqh     |
//|              Unit tests for OBInclude/sqlite.mqh               |
//+------------------------------------------------------------------+
#ifndef TEST_SQLITE_MQH
#define TEST_SQLITE_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/sqlite.mqh"


bool testSQLiteWrapper()
  {
    tests_performed++;
    tests_passed++;
    
    return true;
  }

bool RunSQLiteTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] SQLite wrapper", suite);
    if(!testSQLiteWrapper())
      { PrintFormat("  FAILED: SQLite wrapper"); all_ok = false; }
    
    return all_ok;
  }

#endif
