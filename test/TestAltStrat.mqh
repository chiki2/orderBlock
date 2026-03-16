//+------------------------------------------------------------------+
//|                                             TestAltStrat.mqh   |
//|              Unit tests for OBInclude/altStrat.mqh              |
//+------------------------------------------------------------------+
#ifndef TEST_ALTSTRAT_MQH
#define TEST_ALTSTRAT_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/altStrat.mqh"

bool testAltStratConstants()
  {
    ASSERT_INT(ALT_STRAT_NONE, 0, "ALT_STRAT_NONE == 0");
    ASSERT_INT(ALT_STRAT_FVG, 1, "ALT_STRAT_FVG == 1");
    ASSERT_INT(ALT_STRAT_DISPLACEMENT, 2, "ALT_STRAT_DISPLACEMENT == 2");
    ASSERT_INT(ALT_STRAT_LIQUIDITY_SWEEP, 3, "ALT_STRAT_LIQUIDITY_SWEEP == 3");
    ASSERT_INT(ALT_STRAT_LAST, 4, "ALT_STRAT_LAST == 4");
    
    return true;
  }

bool testAltStratConfig()
  {
    AltStratConfig cfg;
    
    ASSERT_INT(cfg.activeStrategy, 0, "AltStratConfig: default strategy == 0");
    ASSERT_BOOL(cfg.enabled, false, "AltStratConfig: default enabled == false");
    ASSERT_DBL(cfg.minFVGSize, 0.0, "AltStratConfig: default minFVG == 0");
    
    return true;
  }

bool RunAltStratTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] AltStrat constants", suite);
    if(!testAltStratConstants())
      { PrintFormat("  FAILED: AltStrat constants"); all_ok = false; }
    
    PrintFormat("  [%s] AltStrat config", suite);
    if(!testAltStratConfig())
      { PrintFormat("  FAILED: AltStrat config"); all_ok = false; }
    
    return all_ok;
  }

#endif
