//+------------------------------------------------------------------+
//|                                                 TestHelpers.mqh |
//|              Unit tests for OBInclude/helpers.mqh pure functions|
//+------------------------------------------------------------------+
#ifndef TEST_HELPERS_MQH
#define TEST_HELPERS_MQH

// Tolerance for floating-point comparisons
#define HELPERS_EPS 0.0001

#include "../OBInclude/types.mqh"
#include "../OBInclude/cOrderBlock.mqh"
#include "../OBInclude/globals.mqh"

//+------------------------------------------------------------------+
//| Assertion macros                                                 |
//| Require tests_performed / tests_passed globals from the caller  |
//+------------------------------------------------------------------+
#define ASSERT_DBL(actual, expected, msg)                                  \
    do {                                                                   \
        tests_performed++;                                                 \
        if(MathAbs((double)(actual) - (double)(expected)) > HELPERS_EPS) { \
            PrintFormat("  FAIL [" msg "]: expected %.6f, got %.6f",       \
                        (double)(expected), (double)(actual));             \
            return false;                                                  \
        }                                                                  \
        tests_passed++;                                                    \
    } while(false)

#define ASSERT_INT(actual, expected, msg)                        \
    do {                                                         \
        tests_performed++;                                       \
        if((int)(actual) != (int)(expected)) {                   \
            PrintFormat("  FAIL [" msg "]: expected %d, got %d", \
                        (int)(expected), (int)(actual));         \
            return false;                                        \
        }                                                        \
        tests_passed++;                                          \
    } while(false)

#define ASSERT_STR(actual, expected, msg)                            \
    do {                                                             \
        tests_performed++;                                           \
        if((string)(actual) != (string)(expected)) {                 \
            PrintFormat("  FAIL [" msg "]: expected '%s', got '%s'", \
                        (string)(expected), (string)(actual));       \
            return false;                                            \
        }                                                            \
        tests_passed++;                                              \
    } while(false)

#define ASSERT_BOOL(actual, expected, msg)                       \
    do {                                                         \
        tests_performed++;                                       \
        if((bool)(actual) != (bool)(expected)) {                 \
            PrintFormat("  FAIL [" msg "]: expected %s, got %s", \
                        (expected) ? "true" : "false",           \
                        (actual) ? "true" : "false");            \
            return false;                                        \
        }                                                        \
        tests_passed++;                                          \
    } while(false)

//+------------------------------------------------------------------+
//| getFibLevel — zero range (high == low)                          |
//|                                                                  |
//| When range = 0 every level must return the anchor price.        |
//+------------------------------------------------------------------+
bool testFibZeroRange() {
    ASSERT_DBL(getFibLevel(false, 100, 100, 0.5), 100.0, "bull zero-range 50%");
    ASSERT_DBL(getFibLevel(true, 100, 100, 0.5), 100.0, "bear zero-range 50%");
    ASSERT_DBL(getFibLevel(false, 100, 100, 1.618), 100.0, "bull zero-range ext 1.618");
    ASSERT_DBL(getFibLevel(true, 100, 100, 1.618), 100.0, "bear zero-range ext 1.618");
    return true;
}

//+------------------------------------------------------------------+
//| getFibLevel — boundary at level == 1.0                         |
//|                                                                  |
//| At full retracement bull returns low, bear returns high.        |
//+------------------------------------------------------------------+
bool testFibBoundaryLevel() {
    // Simple 0-based range
    ASSERT_DBL(getFibLevel(false, 1000, 0, 1.0), 0.0, "bull level=1.0 == low");
    ASSERT_DBL(getFibLevel(true, 1000, 0, 1.0), 1000.0, "bear level=1.0 == high");

    // Offset range [100, 200]
    ASSERT_DBL(getFibLevel(false, 200, 100, 1.0), 100.0, "bull level=1.0 offset == low");
    ASSERT_DBL(getFibLevel(true, 200, 100, 1.0), 200.0, "bear level=1.0 offset == high");
    return true;
}

//+------------------------------------------------------------------+
//| getFibLevel — standard retracement levels, bullish OB           |
//|                                                                  |
//| Bull: result = high - range * level                             |
//| Uses integer prices so NormalizeDouble is digit-agnostic.       |
//+------------------------------------------------------------------+
bool testFibRetracementBull() {
    // high=1000, low=0, range=1000  -> results are integers
    ASSERT_DBL(getFibLevel(false, 1000, 0, 0.236), 764.0, "bull 23.6%");
    ASSERT_DBL(getFibLevel(false, 1000, 0, 0.382), 618.0, "bull 38.2%");
    ASSERT_DBL(getFibLevel(false, 1000, 0, 0.500), 500.0, "bull 50.0%");
    ASSERT_DBL(getFibLevel(false, 1000, 0, 0.618), 382.0, "bull 61.8%");
    ASSERT_DBL(getFibLevel(false, 1000, 0, 0.786), 214.0, "bull 78.6%");
    return true;
}

//+------------------------------------------------------------------+
//| getFibLevel — standard retracement levels, bearish OB           |
//|                                                                  |
//| Bear: result = low + range * level                              |
//+------------------------------------------------------------------+
bool testFibRetracementBear() {
    // high=1000, low=0, range=1000
    ASSERT_DBL(getFibLevel(true, 1000, 0, 0.236), 236.0, "bear 23.6%");
    ASSERT_DBL(getFibLevel(true, 1000, 0, 0.382), 382.0, "bear 38.2%");
    ASSERT_DBL(getFibLevel(true, 1000, 0, 0.500), 500.0, "bear 50.0%");
    ASSERT_DBL(getFibLevel(true, 1000, 0, 0.618), 618.0, "bear 61.8%");
    ASSERT_DBL(getFibLevel(true, 1000, 0, 0.786), 786.0, "bear 78.6%");
    return true;
}

//+------------------------------------------------------------------+
//| getFibLevel — extension levels (> 1.0)                         |
//|                                                                  |
//| Bull ext:  result = high + range * (level - 1)                 |
//| Bear ext:  pass inverted args (high < low) so range is         |
//|            negative and the formula projects upward.            |
//+------------------------------------------------------------------+
bool testFibExtensions() {
    // --- Bull extensions (high=1000, low=0, range=1000)
    ASSERT_DBL(getFibLevel(false, 1000, 0, 1.272), 1272.0, "bull ext 127.2%");
    ASSERT_DBL(getFibLevel(false, 1000, 0, 1.618), 1618.0, "bull ext 161.8%");
    ASSERT_DBL(getFibLevel(false, 1000, 0, 2.000), 2000.0, "bull ext 200%");

    // --- Bear extensions (high=0, low=1000  =>  range=-1000)
    //     formula: low - range*(level-1) = 1000 - (-1000)*(level-1) = 1000 + 1000*(level-1)
    ASSERT_DBL(getFibLevel(true, 0, 1000, 1.272), 1272.0, "bear ext 127.2%");
    ASSERT_DBL(getFibLevel(true, 0, 1000, 1.618), 1618.0, "bear ext 161.8%");
    ASSERT_DBL(getFibLevel(true, 0, 1000, 2.000), 2000.0, "bear ext 200%");
    return true;
}

//+------------------------------------------------------------------+
//| getFibLevel — symmetry invariant                                |
//|                                                                  |
//| For any retracement level x in (0, 1]:                         |
//|   getFibLevel(bear, H, L, x) + getFibLevel(bull, H, L, x)     |
//|   == H + L                                                      |
//|                                                                  |
//| Proof: bear = L + r*x,  bull = H - r*x  where r = H-L         |
//|        sum  = L + H = constant                                  |
//+------------------------------------------------------------------+
bool testFibSymmetry() {
    double levels[] = {0.236, 0.382, 0.5, 0.618, 0.786, 1.0};

    // Test with range [0, 1000]
    double H1 = 1000, L1 = 0;
    double expected1 = H1 + L1;
    for(int k = 0; k < ArraySize(levels); k++) {
        double bear_val = getFibLevel(true, H1, L1, levels[k]);
        double bull_val = getFibLevel(false, H1, L1, levels[k]);
        tests_performed++;
        if(MathAbs(bear_val + bull_val - expected1) > HELPERS_EPS) {
            PrintFormat("  FAIL [symmetry H=1000 L=0 level=%.3f]: bear=%.4f bull=%.4f sum=%.4f expected=%.4f",
                        levels[k], bear_val, bull_val, bear_val + bull_val, expected1);
            return false;
        }
        tests_passed++;
    }

    // Test with offset range [3990, 4100]
    double H2 = 4100, L2 = 3990;
    double expected2 = H2 + L2;
    double levels2[] = {0.382, 0.5, 0.618};
    for(int k = 0; k < ArraySize(levels2); k++) {
        double bear_val = getFibLevel(true, H2, L2, levels2[k]);
        double bull_val = getFibLevel(false, H2, L2, levels2[k]);
        tests_performed++;
        if(MathAbs(bear_val + bull_val - expected2) > HELPERS_EPS) {
            PrintFormat("  FAIL [symmetry H=4100 L=3990 level=%.3f]: sum=%.4f expected=%.4f",
                        levels2[k], bear_val + bull_val, expected2);
            return false;
        }
        tests_passed++;
    }

    return true;
}

//+------------------------------------------------------------------+
//| helperTrend — maps bool direction to display string             |
//+------------------------------------------------------------------+
bool testHelperTrend() {
    ASSERT_STR(helperTrend(true), "up", "helperTrend(true)  == 'up'");
    ASSERT_STR(helperTrend(false), "down", "helperTrend(false) == 'down'");
    return true;
}

//+------------------------------------------------------------------+
//| CountLines — counts newline characters and adds 1               |
//+------------------------------------------------------------------+
bool testCountLines() {
    ASSERT_INT(CountLines(""), 1, "CountLines: empty string");
    ASSERT_INT(CountLines("hello"), 1, "CountLines: single line");
    ASSERT_INT(CountLines("hello\nworld"), 2, "CountLines: two lines");
    ASSERT_INT(CountLines("a\nb\nc"), 3, "CountLines: three lines");
    ASSERT_INT(CountLines("\n\n\n"), 4, "CountLines: three bare newlines");
    return true;
}

//+------------------------------------------------------------------+
//| orderBlock::getRR — reward / risk ratio                         |
//+------------------------------------------------------------------+
bool testGetRR() {
    cOrderBlock ob; 

    // risk == 0  → guard must return 0.0
    ob.entryPrice = 100.0;
    ob.stopLoss   = 100.0;
    ob.takeProfit = 120.0;
    ASSERT_DBL(ob.getRR(), 0.0, "getRR: zero risk returns 0");

    // 1 : 1
    ob.entryPrice = 100.0;
    ob.stopLoss   = 90.0;
    ob.takeProfit = 110.0;
    ASSERT_DBL(ob.getRR(), 1.0, "getRR: 1:1");

    // 2 : 1
    ob.entryPrice = 100.0;
    ob.stopLoss   = 90.0;
    ob.takeProfit = 120.0;
    ASSERT_DBL(ob.getRR(), 2.0, "getRR: 2:1");

    // 0.5 : 1  (partial / early TP)
    ob.entryPrice = 100.0;
    ob.stopLoss   = 90.0;
    ob.takeProfit = 105.0;
    ASSERT_DBL(ob.getRR(), 0.5, "getRR: 0.5:1");

    // Bear-like setup (SL above entry, TP below entry) — getRR uses MathAbs so
    // it remains direction-agnostic.
    ob.entryPrice = 100.0;
    ob.stopLoss   = 110.0;   // 10 pts above → risk 10
    ob.takeProfit = 70.0;    // 30 pts below → reward 30
    ASSERT_DBL(ob.getRR(), 3.0, "getRR: bear 3:1");

    return true;
}

//+------------------------------------------------------------------+
//| orderBlock::getTPByChange — TP from percentage price move       |
//+------------------------------------------------------------------+
bool testGetTPByChange() {
    cOrderBlock ob;

    // Guard: entryPrice == -1.0 must return false
    ob.entryPrice = -1.0;
    ob.isBear     = false;
    ASSERT_BOOL(ob.getTPByChange(1.0), false, "getTPByChange: guard entryPrice=-1");

    // Bullish: 1 % on 4000  → TP = 4040
    ob.entryPrice = 4000.0;
    ob.isBear     = false;
    ob.getTPByChange(1.0);
    ASSERT_DBL(ob.takeProfit, 4040.0, "getTPByChange: bull 1% on 4000");

    // Bearish: 1 % on 4000  → TP = 3960
    ob.entryPrice = 4000.0;
    ob.isBear     = true;
    ob.getTPByChange(1.0);
    ASSERT_DBL(ob.takeProfit, 3960.0, "getTPByChange: bear 1% on 4000");

    // Bullish: 2 % on 5000  → TP = 5100
    ob.entryPrice = 5000.0;
    ob.isBear     = false;
    ob.getTPByChange(2.0);
    ASSERT_DBL(ob.takeProfit, 5100.0, "getTPByChange: bull 2% on 5000");

    // Bearish: 0.5 % on 2000 → TP = 1990
    ob.entryPrice = 2000.0;
    ob.isBear     = true;
    ob.getTPByChange(0.5);
    ASSERT_DBL(ob.takeProfit, 1990.0, "getTPByChange: bear 0.5% on 2000");

    return true;
}

//+------------------------------------------------------------------+
//| orderBlock::getTPByRRR — additional edge cases                  |
//|                                                                  |
//| getTPByRRR normalises to broker tick size, so all expected TPs  |
//| use integer values that are tick-size-agnostic.                 |
//+------------------------------------------------------------------+
bool testGetTPByRRREdgeCases() {
    cOrderBlock ob;

    // Guard: entry == stopLoss  (risk=0)  → must return false
    ob.entryPrice = 4000.0;
    ob.stopLoss   = 4000.0;
    ob.isBear     = false;
    ASSERT_BOOL(ob.getTPByRRR(1.0), false, "getTPByRRR: zero risk returns false");

    // Bull 2:1  — entry=4000, sl=3900, risk=100, reward=200, TP=4200
    ob.entryPrice = 4000.0;
    ob.stopLoss   = 3900.0;
    ob.isBear     = false;
    ob.getTPByRRR(2.0);
    ASSERT_DBL(ob.takeProfit, 4200.0, "getTPByRRR: bull 2:1");

    // Bull 0.5:1  — entry=4000, sl=3900, risk=100, reward=50, TP=4050
    ob.entryPrice = 4000.0;
    ob.stopLoss   = 3900.0;
    ob.isBear     = false;
    ob.getTPByRRR(0.5);
    ASSERT_DBL(ob.takeProfit, 4050.0, "getTPByRRR: bull 0.5:1");

    // Bear 2:1  — entry=4000, sl=4100, risk=100, reward=200, TP=3800
    ob.entryPrice = 4000.0;
    ob.stopLoss   = 4100.0;
    ob.isBear     = true;
    ob.getTPByRRR(2.0);
    ASSERT_DBL(ob.takeProfit, 3800.0, "getTPByRRR: bear 2:1");

    // Bear 3:1  — entry=4000, sl=4100, risk=100, reward=300, TP=3700
    ob.entryPrice = 4000.0;
    ob.stopLoss   = 4100.0;
    ob.isBear     = true;
    ob.getTPByRRR(3.0);
    ASSERT_DBL(ob.takeProfit, 3700.0, "getTPByRRR: bear 3:1");

    // Consistency: getRR() after getTPByRRR() must round-trip to the same ratio
    ob.entryPrice = 4000.0;
    ob.stopLoss   = 3900.0;
    ob.isBear     = false;
    ob.getTPByRRR(3.0);
    ASSERT_DBL(ob.getRR(), 3.0, "getTPByRRR -> getRR round-trip 3:1");

    return true;
}

//+------------------------------------------------------------------+
//| GetTrendAngle — pure atan2-based angle from two bar/price points|
//+------------------------------------------------------------------+
bool testGetTrendAngle() {
    // Horizontal line: dy=0  -> angle = 0°
    ASSERT_DBL(GetTrendAngle(0, 0, 10, 0),   0.0,  "GetTrendAngle: horizontal -> 0°");

    // 45° upward: dy == dx
    ASSERT_DBL(GetTrendAngle(0, 0, 10, 10),  45.0, "GetTrendAngle: 45° up");

    // 45° downward: dy == -dx
    ASSERT_DBL(GetTrendAngle(0, 10, 10, 0), -45.0, "GetTrendAngle: 45° down");

    // Vertical up: dx=0, dy>0  -> 90°
    ASSERT_DBL(GetTrendAngle(0, 0,  0, 10),  90.0, "GetTrendAngle: vertical up -> 90°");

    // Vertical down: dx=0, dy<0  -> -90°
    ASSERT_DBL(GetTrendAngle(0, 10, 0,  0), -90.0, "GetTrendAngle: vertical down -> -90°");

    // Symmetry: swapping start/end negates the angle
    tests_performed++;
    double a1 = GetTrendAngle(0, 0, 5, 3);
    double a2 = GetTrendAngle(0, 3, 5, 0);
    if(MathAbs(a1 + a2) > HELPERS_EPS) {
        PrintFormat("  FAIL [GetTrendAngle symmetry]: a1=%.4f  a2=%.4f", a1, a2);
        return false;
    }
    tests_passed++;

    return true;
}


//+------------------------------------------------------------------+
//| ArrayPopFront — removes the first element of a double array     |
//+------------------------------------------------------------------+
bool testArrayPopFront() {
    // Guard: size == 1  -> no-op (size stays 1, value unchanged)
    double arr1[];
    ArrayResize(arr1, 1);
    arr1[0] = 99.0;
    ArrayPopFront(arr1);
    ASSERT_INT(ArraySize(arr1), 1,    "ArrayPopFront: size=1 no-op size");
    ASSERT_DBL(arr1[0],         99.0, "ArrayPopFront: size=1 no-op value");

    // Size == 2: front removed, second becomes first
    double arr2[];
    ArrayResize(arr2, 2);
    arr2[0] = 10.0;
    arr2[1] = 20.0;
    ArrayPopFront(arr2);
    ASSERT_INT(ArraySize(arr2), 1,    "ArrayPopFront: size=2 -> size=1");
    ASSERT_DBL(arr2[0],         20.0, "ArrayPopFront: size=2 -> arr[0]==20");

    // Size == 5: front removed, remaining 4 shifted
    double arr5[];
    ArrayResize(arr5, 5);
    arr5[0] = 1.0;  arr5[1] = 2.0;  arr5[2] = 3.0;
    arr5[3] = 4.0;  arr5[4] = 5.0;
    ArrayPopFront(arr5);
    ASSERT_INT(ArraySize(arr5), 4,   "ArrayPopFront: size=5 -> size=4");
    ASSERT_DBL(arr5[0],         2.0, "ArrayPopFront: arr[0] shifted to 2");
    ASSERT_DBL(arr5[1],         3.0, "ArrayPopFront: arr[1] shifted to 3");
    ASSERT_DBL(arr5[3],         5.0, "ArrayPopFront: arr[3] == 5");

    // Two successive pops
    ArrayPopFront(arr5);
    ASSERT_INT(ArraySize(arr5), 3,   "ArrayPopFront: second pop -> size=3");
    ASSERT_DBL(arr5[0],         3.0, "ArrayPopFront: second pop -> arr[0]==3");

    return true;
}


//+------------------------------------------------------------------+
//| FormatTextWithLineBreaks — pure word-wrap into a string array   |
//|                                                                  |
//| Returns a string-encoded line count; fills lines[] output array.|
//+------------------------------------------------------------------+
bool testFormatTextWithLineBreaks() {
    string lines[];

    // --- Single short word: must produce 1 line
    string ret1 = FormatTextWithLineBreaks("hi", 1000, 10, lines);
    ASSERT_INT(StringToInteger(ret1), 1, "FormatText: single word -> 1 line");
    ASSERT_INT(ArraySize(lines),      1, "FormatText: lines[] size == 1");
    ASSERT_STR(lines[0], "hi",           "FormatText: lines[0] == 'hi'");

    // --- Two short words that fit together on one line
    //     maxWidth=1000, fontSize=10: maxCharsPerLine = (1000-20)/(10*0.55) = 178
    //     "hello world" (11 chars) <= 178  -> 1 line
    ArrayResize(lines, 0);
    string ret2 = FormatTextWithLineBreaks("hello world", 1000, 10, lines);
    ASSERT_INT(StringToInteger(ret2), 1, "FormatText: 'hello world' fits on 1 line");
    ASSERT_INT(ArraySize(lines),      1, "FormatText: lines[] size == 1 for 2-word fit");

    // --- Words that require wrapping
    //     maxWidth=100, fontSize=10: maxCharsPerLine = (100-20)/(10*0.55) = 14
    //     "hello world foo" -> "hello world"(11)<=14 fits, then "foo" wraps -> 2 lines
    ArrayResize(lines, 0);
    string ret3 = FormatTextWithLineBreaks("hello world foo", 100, 10, lines);
    ASSERT_INT(StringToInteger(ret3), 2, "FormatText: wrapping -> 2 lines");
    ASSERT_INT(ArraySize(lines),      2, "FormatText: lines[] size == 2 after wrap");
    ASSERT_STR(lines[0], "hello world",  "FormatText: first line == 'hello world'");
    ASSERT_STR(lines[1], "foo",          "FormatText: second line == 'foo'");

    // --- Return value matches ArraySize
    tests_performed++;
    if(StringToInteger(ret3) != ArraySize(lines)) {
        PrintFormat("  FAIL [FormatText return/size mismatch]: ret=%s size=%d",
                    ret3, ArraySize(lines));
        return false;
    }
    tests_passed++;

    return true;
}


//+------------------------------------------------------------------+
//| getUninitReasonText — pure switch: int reason code -> string    |
//+------------------------------------------------------------------+
bool testGetUninitReasonText() {
    // Each known reason constant must produce a non-empty string
    // containing the expected keyword fragment.
    tests_performed++;
    if(StringFind(getUninitReasonText(REASON_ACCOUNT),     "Account") < 0) {
        PrintFormat("  FAIL [getUninitReasonText REASON_ACCOUNT]: got '%s'",
                    getUninitReasonText(REASON_ACCOUNT));
        return false;
    }
    tests_passed++;

    tests_performed++;
    if(StringFind(getUninitReasonText(REASON_CHARTCHANGE), "Symbol or timeframe") < 0) {
        PrintFormat("  FAIL [getUninitReasonText REASON_CHARTCHANGE]: got '%s'",
                    getUninitReasonText(REASON_CHARTCHANGE));
        return false;
    }
    tests_passed++;

    tests_performed++;
    if(StringFind(getUninitReasonText(REASON_CHARTCLOSE),  "Chart was closed") < 0) {
        PrintFormat("  FAIL [getUninitReasonText REASON_CHARTCLOSE]: got '%s'",
                    getUninitReasonText(REASON_CHARTCLOSE));
        return false;
    }
    tests_passed++;

    tests_performed++;
    if(StringFind(getUninitReasonText(REASON_PARAMETERS),  "Input-parameter") < 0) {
        PrintFormat("  FAIL [getUninitReasonText REASON_PARAMETERS]: got '%s'",
                    getUninitReasonText(REASON_PARAMETERS));
        return false;
    }
    tests_passed++;

    tests_performed++;
    if(StringFind(getUninitReasonText(REASON_REMOVE),      "removed from chart") < 0) {
        PrintFormat("  FAIL [getUninitReasonText REASON_REMOVE]: got '%s'",
                    getUninitReasonText(REASON_REMOVE));
        return false;
    }
    tests_passed++;

    tests_performed++;
    if(StringFind(getUninitReasonText(REASON_TEMPLATE),    "template") < 0) {
        PrintFormat("  FAIL [getUninitReasonText REASON_TEMPLATE]: got '%s'",
                    getUninitReasonText(REASON_TEMPLATE));
        return false;
    }
    tests_passed++;

    // Default/unknown: any integer not matching a case must give "Another reason"
    tests_performed++;
    if(StringFind(getUninitReasonText(9999), "Another reason") < 0) {
        PrintFormat("  FAIL [getUninitReasonText default]: got '%s'",
                    getUninitReasonText(9999));
        return false;
    }
    tests_passed++;

    return true;
}


//+------------------------------------------------------------------+
//| MaxTheoreticalBars — ratio of PeriodSeconds() values            |
//|                                                                  |
//| Uses PeriodSeconds() which is a pure MQL5 converter (no market  |
//| data). Inverted pair (tfBig < tfSmall) must return 0.           |
//+------------------------------------------------------------------+
bool testMaxTheoreticalBars() {
    // H4 / H1 = 14400 / 3600 = 4
    ASSERT_INT(MaxTheoreticalBars(PERIOD_H4, PERIOD_H1),  4,  "MaxTheoreticalBars: H4/H1==4");

    // D1 / H1 = 86400 / 3600 = 24
    ASSERT_INT(MaxTheoreticalBars(PERIOD_D1, PERIOD_H1),  24, "MaxTheoreticalBars: D1/H1==24");

    // H1 / M15 = 3600 / 900 = 4
    ASSERT_INT(MaxTheoreticalBars(PERIOD_H1, PERIOD_M15), 4,  "MaxTheoreticalBars: H1/M15==4");

    // M15 / M1 = 900 / 60 = 15
    ASSERT_INT(MaxTheoreticalBars(PERIOD_M15, PERIOD_M1), 15, "MaxTheoreticalBars: M15/M1==15");

    // Inverted pair: H1 > D1 is false -> secBig < secSmall -> return 0
    ASSERT_INT(MaxTheoreticalBars(PERIOD_H1, PERIOD_D1),  0,  "MaxTheoreticalBars: H1/D1 inverted==0");

    return true;
}


//+------------------------------------------------------------------+
//| RunHelpersTests                                                  |
//|                                                                  |
//| Entry point called by TestOrderBlock. Runs every test group and |
//| continues even when one group fails, so all failures are seen.  |
//| Returns false if any group failed.                              |
//+------------------------------------------------------------------+
bool RunHelpersTests(const string suite) {
    bool all_ok = true;

    PrintFormat("  [%s] getFibLevel: zero range", suite);
    if(!testFibZeroRange()) {
        PrintFormat("  FAILED: getFibLevel zero range");
        all_ok = false;
    }

    PrintFormat("  [%s] getFibLevel: boundary level=1.0", suite);
    if(!testFibBoundaryLevel()) {
        PrintFormat("  FAILED: getFibLevel boundary level");
        all_ok = false;
    }

    PrintFormat("  [%s] getFibLevel: retracement bullish", suite);
    if(!testFibRetracementBull()) {
        PrintFormat("  FAILED: getFibLevel retracement bull");
        all_ok = false;
    }

    PrintFormat("  [%s] getFibLevel: retracement bearish", suite);
    if(!testFibRetracementBear()) {
        PrintFormat("  FAILED: getFibLevel retracement bear");
        all_ok = false;
    }

    PrintFormat("  [%s] getFibLevel: extensions (>1.0)", suite);
    if(!testFibExtensions()) {
        PrintFormat("  FAILED: getFibLevel extensions");
        all_ok = false;
    }

    PrintFormat("  [%s] getFibLevel: symmetry invariant", suite);
    if(!testFibSymmetry()) {
        PrintFormat("  FAILED: getFibLevel symmetry");
        all_ok = false;
    }

    PrintFormat("  [%s] helperTrend", suite);
    if(!testHelperTrend()) {
        PrintFormat("  FAILED: helperTrend");
        all_ok = false;
    }

    PrintFormat("  [%s] CountLines", suite);
    if(!testCountLines()) {
        PrintFormat("  FAILED: CountLines");
        all_ok = false;
    }

    PrintFormat("  [%s] getRR", suite);
    if(!testGetRR()) {
        PrintFormat("  FAILED: getRR");
        all_ok = false;
    }

    PrintFormat("  [%s] getTPByChange", suite);
    if(!testGetTPByChange()) {
        PrintFormat("  FAILED: getTPByChange");
        all_ok = false;
    }

    PrintFormat("  [%s] getTPByRRR edge cases", suite);
    if(!testGetTPByRRREdgeCases()) {
        PrintFormat("  FAILED: getTPByRRR edge cases");
        all_ok = false;
    }

    PrintFormat("  [%s] GetTrendAngle", suite);
    if(!testGetTrendAngle()) {
        PrintFormat("  FAILED: GetTrendAngle");
        all_ok = false;
    }

    PrintFormat("  [%s] ArrayPopFront", suite);
    if(!testArrayPopFront()) {
        PrintFormat("  FAILED: ArrayPopFront");
        all_ok = false;
    }

    PrintFormat("  [%s] FormatTextWithLineBreaks", suite);
    if(!testFormatTextWithLineBreaks()) {
        PrintFormat("  FAILED: FormatTextWithLineBreaks");
        all_ok = false;
    }

    PrintFormat("  [%s] getUninitReasonText", suite);
    if(!testGetUninitReasonText()) {
        PrintFormat("  FAILED: getUninitReasonText");
        all_ok = false;
    }

    PrintFormat("  [%s] MaxTheoreticalBars", suite);
    if(!testMaxTheoreticalBars()) {
        PrintFormat("  FAILED: MaxTheoreticalBars");
        all_ok = false;
    }

    return all_ok;
}

#endif   // TEST_HELPERS_MQH
