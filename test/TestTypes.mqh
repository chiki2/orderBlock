//+------------------------------------------------------------------+
//|                                               TestTypes.mqh     |
//|              Unit tests for OBInclude/types.mqh                 |
//+------------------------------------------------------------------+
#ifndef TEST_TYPES_MQH
#define TEST_TYPES_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/types.mqh"

bool testOrderBlockFields()
  {
    orderBlock ob;
    
    ASSERT_INT(ob.stars, 0, "default: stars == 0");
    ASSERT_BOOL(ob.isBear, false, "default: isBear == false");
    ASSERT_BOOL(ob.isDone, false, "default: isDone == false");
    ASSERT_BOOL(ob.isMitigated, false, "default: isMitigated == false");
    ASSERT_BOOL(ob.isMSS, false, "default: isMSS == false");
    ASSERT_BOOL(ob.isImbalanced, false, "default: isImbalanced == false");
    ASSERT_BOOL(ob.hasChoch, false, "default: hasChoch == false");
    ASSERT_BOOL(ob.isBOS, false, "default: isBOS == false");
    ASSERT_DBL(ob.highPrice, 0.0, "default: highPrice == 0");
    ASSERT_DBL(ob.lowPrice, 0.0, "default: lowPrice == 0");
    ASSERT_DBL(ob.entryPrice, -1.0, "default: entryPrice == -1");
    ASSERT_DBL(ob.stopLoss, -1.0, "default: stopLoss == -1");
    ASSERT_DBL(ob.takeProfit, -1.0, "default: takeProfit == -1");
    ASSERT_DBL(ob.OBBody, 0.0, "default: OBBody == 0");
    ASSERT_DBL(ob.OBWick, 0.0, "default: OBWick == 0");
    
    return true;
  }

bool testNoTradeReasonEnum()
  {
    ASSERT_INT((int)ENUM_REASON_INIT, 0, "NoTradeReason: INIT == 0");
    ASSERT_INT((int)ENUM_NO_REASON, 1, "NoTradeReason: NO_REASON == 1");
    ASSERT_INT((int)ENUM_REASON_ISMITIGATED, 2, "NoTradeReason: ISMITIGATED == 2");
    ASSERT_INT((int)ENUM_REASON_ISDONE, 3, "NoTradeReason: ISDONE == 3");
    ASSERT_INT((int)ENUM_REASON_NO_BOS, 4, "NoTradeReason: NO_BOS == 4");
    ASSERT_INT((int)ENUM_REASON_NO_MSS, 5, "NoTradeReason: NO_MSS == 5");
    ASSERT_INT((int)ENUM_REASON_NO_LIQUIDITY_SWEPT_BEFORE, 6, "NoTradeReason: NO_LIQ_SWEEP == 6");
    ASSERT_INT((int)ENUM_REASON_IS_OVERDUE, 7, "NoTradeReason: IS_OVERDUE == 7");
    ASSERT_INT((int)ENUM_REASON_IS_NOT_DISCOUNT, 8, "NoTradeReason: NOT_DISCOUNT == 8");
    ASSERT_INT((int)ENUM_REASON_IS_NOT_PREMIUM, 9, "NoTradeReason: NOT_PREMIUM == 9");
    ASSERT_INT((int)ENUM_REASON_IS_LOW_IMBALANCE, 10, "NoTradeReason: LOW_IMBALANCE == 10");
    ASSERT_INT((int)ENUM_REASON_IS_COUNTER_BEARISH, 11, "NoTradeReason: COUNTER_BEARISH == 11");
    ASSERT_INT((int)ENUM_REASON_IS_COUNTER_BULLISH, 12, "NoTradeReason: COUNTER_BULLISH == 12");
    ASSERT_INT((int)ENUM_REASON_WEAK_IMPULSE, 13, "NoTradeReason: WEAK_IMPULSE == 13");
    ASSERT_INT((int)ENUM_REASON_IMBALANCED_FILLED, 14, "NoTradeReason: IMBALANCED_FILLED == 14");
    ASSERT_INT((int)ENUM_REASON_IMBALANCED_NOT_FILLED, 15, "NoTradeReason: IMBALANCED_NOT_FILLED == 15");
    ASSERT_INT((int)ENUM_REASON_OPPOSITE_OB, 16, "NoTradeReason: OPPOSITE_OB == 16");
    
    return true;
  }

bool testEntryTypeEnum()
  {
    ASSERT_INT((int)ENUM_ENTRY_FVG, 0, "entryType: FVG == 0");
    ASSERT_INT((int)ENUM_ENTRY_F50, 1, "entryType: F50 == 1");
    ASSERT_INT((int)ENUM_ENTRY_OBOPEN, 2, "entryType: OBOPEN == 2");
    return true;
  }

bool testMarketTrendEnum()
  {
    ASSERT_INT((int)TREND_RANGE, 0, "MarketTrend: RANGE == 0");
    ASSERT_INT((int)TREND_BULLISH, 1, "MarketTrend: BULLISH == 1");
    ASSERT_INT((int)TREND_BEARISH, -1, "MarketTrend: BEARISH == -1");
    ASSERT_INT((int)TREND_UKNOWN, -42, "MarketTrend: UNKNOWN == -42");
    return true;
  }

bool testLangEnum()
  {
    ASSERT_INT((int)LANG_EN, 0, "Lang: EN == 0");
    ASSERT_INT((int)LANG_FR, 1, "Lang: FR == 1");
    ASSERT_INT((int)LANG_ES, 2, "Lang: ES == 2");
    ASSERT_INT((int)LANG_DE, 3, "Lang: DE == 3");
    return true;
  }

bool RunTypesTests(const string suite)
  {
    bool all_ok = true;
    
    PrintFormat("  [%s] orderBlock default fields", suite);
    if(!testOrderBlockFields())
      { PrintFormat("  FAILED: orderBlock fields"); all_ok = false; }
    
    PrintFormat("  [%s] NoTradeReason enum", suite);
    if(!testNoTradeReasonEnum())
      { PrintFormat("  FAILED: NoTradeReason enum"); all_ok = false; }
    
    PrintFormat("  [%s] entryType enum", suite);
    if(!testEntryTypeEnum())
      { PrintFormat("  FAILED: entryType enum"); all_ok = false; }
    
    PrintFormat("  [%s] MarketTrend enum", suite);
    if(!testMarketTrendEnum())
      { PrintFormat("  FAILED: MarketTrend enum"); all_ok = false; }
    
    PrintFormat("  [%s] Lang enum", suite);
    if(!testLangEnum())
      { PrintFormat("  FAILED: Lang enum"); all_ok = false; }
    
    return all_ok;
  }

#endif
