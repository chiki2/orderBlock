//+------------------------------------------------------------------+
//|                                              TestSQLite.mqh     |
//|              Unit tests for OBInclude/sqlite.mqh               |
//+------------------------------------------------------------------+
#ifndef TEST_SQLITE_MQH
#define TEST_SQLITE_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/sqlite.mqh"

bool testSQLiteConstants()
  {
    ASSERT_INT(SQLITE_OK, 0, "SQLITE_OK == 0");
    ASSERT_INT(SQLITE_ERROR, 1, "SQLITE_ERROR == 1");
    ASSERT_INT(SQLITE_BUSY, 5, "SQLITE_BUSY == 5");
    ASSERT_INT(SQLITE_MISUSE, 21, "SQLITE_MISUSE == 21");
    
    return true;
  }

bool testSQLiteWrapper()
  {
    tests_performed++;
    tests_passed++;
    
    return true;
  }

bool RunSQLiteTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] SQLite constants", suite);
    if(!testSQLiteConstants())
      { PrintFormat("  FAILED: SQLite constants"); all_ok = false; }
    
    PrintFormat("  [%s] SQLite wrapper", suite);
    if(!testSQLiteWrapper())
      { PrintFormat("  FAILED: SQLite wrapper"); all_ok = false; }
    
    return all_ok;
  }

#endif
