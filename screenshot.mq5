//+------------------------------------------------------------------+
//|                                                   screenshot.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
  generate a code to send a chart screenshot by email
// To send a chart screenshot by email using MQL5, you need to follow these steps:
// 
// 1. Capture the chart screenshot.
// 2. Save the screenshot to a file.
// 3. Send the file via email.
// 
// Below is a basic example of how you can achieve this in MQL5. Note that you need to have your email settings configured in MetaTrader 5 (`Tools` -> `Options` -> `Email` tab).
// 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Capture the screenshot
   string screenshotFileName = "ChartScreenshot.png";
   if(CaptureScreenshot(screenshotFileName))
     {
      // Send the screenshot via email
      if(SendEmailWithAttachment("Chart Screenshot", "Please find the attached chart screenshot.", screenshotFileName))
         Print("Email sent successfully.");
      else
         Print("Failed to send email.");
     }
   else
      Print("Failed to capture screenshot.");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Capture a screenshot of the current chart                        |
//+------------------------------------------------------------------+
bool CaptureScreenshot(string fileName)
  {
   // Capture the screenshot and save it to the terminal's common folder
   return ChartScreenShot(0, fileName, 1024, 768, ALIGN_LEFT);
  }

//+------------------------------------------------------------------+
//| Send an email with an attachment                                 |
//+------------------------------------------------------------------+
bool SendEmailWithAttachment(string subject, string body, string attachmentFileName)
  {
   // Construct the full path to the file
   string filePath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\MetaQuotes\\Terminal\\Common\\" + attachmentFileName;

   // Send the email
   return SendMail(subject, body, filePath);
  }

//+------------------------------------------------------------------+

// 
// ### Important Notes:
// 
// 1. **Email Configuration**: Ensure that your email settings are correctly configured in MetaTrader 5. You can do this by navigating to `Tools` -> `Options` -> `Email` tab. Fill in the necessary SMTP server details and your email credentials.
// 
// 2. **File Path**: The `ChartScreenShot` function saves the screenshot in the terminal's common folder. The `TerminalInfoString(TERMINAL_COMMONDATA_PATH)` function is used to get the path to this folder.
// 
// 3. **Permissions**: Ensure that MetaTrader 5 has the necessary permissions to access the file system and send emails.
// 
// 4. **Error Handling**: This example includes basic error handling with `Print` statements. You might want to implement more robust error handling depending on your needs.
// 
// 5. **Testing**: Always test the email functionality with a small test email to ensure that everything is set up correctly before using it in a live environment.
// 

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
//---
   
  }
//+------------------------------------------------------------------+
