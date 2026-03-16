//+------------------------------------------------------------------+
//|                                         TestDiagnosticPanel.mqh |
//|              Unit tests for OBInclude/diagnosticPanel.mqh      |
//+------------------------------------------------------------------+
#ifndef TEST_DIAGNOSTICPANEL_MQH
#define TEST_DIAGNOSTICPANEL_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/diagnosticPanel.mqh"

bool testDiagnosticPanelConfig()
  {
    DiagnosticConfig cfg;
    
    ASSERT_BOOL(cfg.enabled, false, "DiagnosticConfig: default enabled == false");
    ASSERT_BOOL(cfg.showOBs, true, "DiagnosticConfig: default showOBs == true");
    ASSERT_BOOL(cfg.showMSS, true, "DiagnosticConfig: default showMSS == true");
    ASSERT_BOOL(cfg.showFVG, true, "DiagnosticConfig: default showFVG == true");
    ASSERT_INT(cfg.refreshInterval, 1000, "DiagnosticConfig: default refresh == 1000ms");
    
    return true;
  }

bool RunDiagnosticPanelTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] DiagnosticPanel config", suite);
    if(!testDiagnosticPanelConfig())
      { PrintFormat("  FAILED: DiagnosticPanel config"); all_ok = false; }
    
    return all_ok;
  }

#endif
