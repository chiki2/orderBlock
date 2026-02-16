//+------------------------------------------------------------------+
//|                                                   TestLangs.mqh |
//|            Unit tests for OBInclude/langs.mqh                   |
//|                                                                  |
//| Tests the T() translation function and GetEnumDescription().    |
//|                                                                  |
//| IMPORTANT: `language` is declared in OrderBlock.mq5. This file  |
//| modifies it temporarily and restores it after each group so it  |
//| does not affect EA behaviour.                                    |
//+------------------------------------------------------------------+
#ifndef TEST_LANGS_MQH
#define TEST_LANGS_MQH

#include "TestHelpers.mqh"
#include "../OBInclude/langs.mqh"

// Re-use assertion macros from TestHelpers.mqh (included before this file)

//+------------------------------------------------------------------+
//| T() — English (LANG_EN / default)                               |
//|                                                                  |
//| EN acts as pass-through: T(key) == key for every known key.     |
//| Unknown keys get the "(NEED Traduction)" fallback suffix.       |
//+------------------------------------------------------------------+
bool testTranslationEN()
  {
   Lang saved = language;
   language   = LANG_EN;

// Boolean display strings
   ASSERT_STR(T("True"),  "True",  "EN: T(True)");
   ASSERT_STR(T("False"), "False", "EN: T(False)");

// Trend direction labels
   ASSERT_STR(T("up"),   "up",   "EN: T(up)");
   ASSERT_STR(T("down"), "down", "EN: T(down)");

// Generic status strings
   ASSERT_STR(T("Warning !"),    "Warning !",    "EN: T(Warning !)");
   ASSERT_STR(T("Init"),         "Init",         "EN: T(Init)");
   ASSERT_STR(T("Status: "),     "Status: ",     "EN: T(Status:)");
   ASSERT_STR(T("Opened"),       "Opened",       "EN: T(Opened)");
   ASSERT_STR(T("Closed"),       "Closed",       "EN: T(Closed)");

// OB lifecycle messages
   ASSERT_STR(T("OB is mitigated"),         "OB is mitigated",         "EN: OB is mitigated");
   ASSERT_STR(T("OB is done, soon deleted"), "OB is done, soon deleted", "EN: OB is done");
   ASSERT_STR(T("OB is overdue"),            "OB is overdue",            "EN: OB is overdue");

// Trade reason messages
   ASSERT_STR(T("No problem, trade can be filled"),
              "No problem, trade can be filled",
              "EN: no problem reason");
   ASSERT_STR(T("Imbalanced is filled"),
              "Imbalanced is filled",
              "EN: imbalanced filled");
   ASSERT_STR(T("A trade is ongoing"),
              "A trade is ongoing",
              "EN: trade ongoing");

// Fibonacci messages
   ASSERT_STR(T("Price has not crossed fibonacci 127 level yet"),
              "Price has not crossed fibonacci 127 level yet",
              "EN: fib 127 not crossed");
   ASSERT_STR(T("Price crossed fibonacci 127 level. Wait for reversal"),
              "Price crossed fibonacci 127 level. Wait for reversal",
              "EN: fib 127 crossed");

   language = saved;
   return true;
  }


//+------------------------------------------------------------------+
//| T() — French (LANG_FR)                                          |
//|                                                                  |
//| Only strings without accented chars are checked to avoid any    |
//| source-encoding ambiguity across platforms.                      |
//+------------------------------------------------------------------+
bool testTranslationFR()
  {
   Lang saved = language;
   language   = LANG_FR;

// Simple vocabulary words (no accents)
   ASSERT_STR(T("up"),   "Haussier", "FR: up -> Haussier");
   ASSERT_STR(T("down"), "Baissier", "FR: down -> Baissier");

// Boolean display
   ASSERT_STR(T("True"),  "Vrai", "FR: True -> Vrai");
   ASSERT_STR(T("False"), "Faux", "FR: False -> Faux");

// Alert
   ASSERT_STR(T("Warning !"), "Attention !", "FR: Warning -> Attention");

// Init
   ASSERT_STR(T("Init"), "Initialisation", "FR: Init -> Initialisation");

// Session names (no accents in the French translations)
   ASSERT_STR(T("Opened"), "Ouvert", "FR: Opened -> Ouvert");
   ASSERT_STR(T("Closed"), "Fermé",  "FR: Closed -> Ferme (accent)");

// OB lifecycle
   ASSERT_STR(T("OB is overdue"), "Order Block périmé", "FR: overdue");

   language = saved;
   return true;
  }


//+------------------------------------------------------------------+
//| T() — Fallback for unknown keys                                  |
//|                                                                  |
//| Any key with no matching translation returns                     |
//|   key + " (NEED Traduction, please pm me)"                      |
//| This holds for all language settings (the fallback is after the |
//| closing brace of the switch statement).                          |
//+------------------------------------------------------------------+
bool testTranslationFallback()
  {
   string unknown = "THIS_KEY_DOES_NOT_EXIST_XYZ";
   string suffix  = " (NEED Traduction, please pm me)";

// LANG_EN — unknown key hits the break and falls to the final return
   Lang saved = language;
   language   = LANG_EN;
   string result_en = T(unknown);
   tests_performed++;
   if(StringFind(result_en, suffix) < 0)
     {
      PrintFormat("  FAIL [T() fallback EN]: got '%s'", result_en);
      language = saved;
      return false;
     }
   tests_passed++;

// LANG_FR — same fallback applies
   language = LANG_FR;
   string result_fr = T(unknown);
   tests_performed++;
   if(StringFind(result_fr, suffix) < 0)
     {
      PrintFormat("  FAIL [T() fallback FR]: got '%s'", result_fr);
      language = saved;
      return false;
     }
   tests_passed++;

// The fallback must preserve the original key as a prefix
   tests_performed++;
   if(StringFind(result_en, unknown) != 0)
     {
      PrintFormat("  FAIL [T() fallback prefix]: original key not at start, got '%s'", result_en);
      language = saved;
      return false;
     }
   tests_passed++;

   language = saved;
   return true;
  }


//+------------------------------------------------------------------+
//| T() — Unknown keys in non-EN languages fall back identically    |
//|                                                                  |
//| LANG_ES and LANG_DE share the `default:` branch with LANG_EN,   |
//| so known EN keys pass through unchanged.                         |
//+------------------------------------------------------------------+
bool testTranslationDefaultFallthrough()
  {
   Lang saved = language;

// LANG_ES falls through to EN default
   language = LANG_ES;
   ASSERT_STR(T("True"),  "True",  "ES falls to EN default: True");
   ASSERT_STR(T("Init"),  "Init",  "ES falls to EN default: Init");

// LANG_DE falls through to EN default
   language = LANG_DE;
   ASSERT_STR(T("True"),  "True",  "DE falls to EN default: True");
   ASSERT_STR(T("up"),    "up",    "DE falls to EN default: up");

   language = saved;
   return true;
  }


//+------------------------------------------------------------------+
//| GetEnumDescription() — maps NoTradeReason enum to T() strings   |
//|                                                                  |
//| Tests that each enum value returns the expected translated text. |
//| Both EN (passthrough) and FR variants are checked.              |
//+------------------------------------------------------------------+
bool testGetEnumDescription()
  {
   Lang saved = language;

//--- English
   language = LANG_EN;

   ASSERT_STR(GetEnumDescription(ENUM_REASON_INIT),
              "Init",
              "EN: ENUM_REASON_INIT");

   ASSERT_STR(GetEnumDescription(ENUM_NO_REASON),
              "No problem, trade can be filled",
              "EN: ENUM_NO_REASON");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_ISMITIGATED),
              "OB is mitigated",
              "EN: ENUM_REASON_ISMITIATED");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_ISDONE),
              "OB is done, soon deleted",
              "EN: ENUM_REASON_ISDONE");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_IS_OVERDUE),
              "OB is overdue",
              "EN: ENUM_REASON_IS_OVERDUE");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_IMBALANCED_FILLED),
              "Imbalanced is filled",
              "EN: ENUM_REASON_IMBALANCED_FILLED");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_IMBALANCED_NOT_FILLED),
              "Imbalanced is not filled",
              "EN: ENUM_REASON_IMBALANCED_NOT_FILLED");

   ASSERT_STR(GetEnumDescription(ENUM_LACK_STARS),
              "Not enough stars to trade",
              "EN: ENUM_LACK_STARS");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_TRADE_ONGOING),
              "A trade is ongoing",
              "EN: ENUM_REASON_TRADE_ONGOING");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_NOT_CROSSED_127),
              "Price has not crossed fibonacci 127 level yet",
              "EN: ENUM_REASON_NOT_CROSSED_127");

   ASSERT_STR(GetEnumDescription(ENUM_REASON_CROSSED_127),
              "Price crossed fibonacci 127 level. Wait for reversal",
              "EN: ENUM_REASON_CROSSED_127");

//--- French (no-accent values)
   language = LANG_FR;

   ASSERT_STR(GetEnumDescription(ENUM_REASON_INIT),
              "Initialisation",
              "FR: ENUM_REASON_INIT");

   language = saved;
   return true;
  }


//+------------------------------------------------------------------+
//| RunLangsTests — entry point called by TestOrderBlock            |
//+------------------------------------------------------------------+
bool RunLangsTests(const string suite)
  {
   bool all_ok = true;

   PrintFormat("  [%s] T(): English passthrough", suite);
   if(!testTranslationEN())
     { PrintFormat("  FAILED: T() English"); all_ok = false; }

   PrintFormat("  [%s] T(): French translations", suite);
   if(!testTranslationFR())
     { PrintFormat("  FAILED: T() French"); all_ok = false; }

   PrintFormat("  [%s] T(): unknown key fallback", suite);
   if(!testTranslationFallback())
     { PrintFormat("  FAILED: T() fallback"); all_ok = false; }

   PrintFormat("  [%s] T(): ES/DE fall through to EN default", suite);
   if(!testTranslationDefaultFallthrough())
     { PrintFormat("  FAILED: T() ES/DE fallthrough"); all_ok = false; }

   PrintFormat("  [%s] GetEnumDescription()", suite);
   if(!testGetEnumDescription())
     { PrintFormat("  FAILED: GetEnumDescription"); all_ok = false; }

   return all_ok;
  }

#endif // TEST_LANGS_MQH
