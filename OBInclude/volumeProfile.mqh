//+------------------------------------------------------------------+
//|                                         VolumeProfileHelper.mqh   |
//|                        Copyright 2026, Charles-Antoine Fournel   |
//|                                             https://orderblock.io|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Charles-Antoine Fournel"
#property link      "https://orderblock.io"

#ifndef VOLUME_PROFILE_HELPER_MQH
#define VOLUME_PROFILE_HELPER_MQH

#define VP_INDICATOR_NAME "VolumeProfile"

struct VolumeProfileData
{
   double            pocPrice;
   double            vahPrice;
   double            valPrice;
   double            totalVolume;
   datetime          profileTime;
   bool              isValid;
};

class CVPHelper
{
private:
   int               m_handle;
   double            m_pocBuffer[];
   double            m_vahBuffer[];
   double            m_valBuffer[];
   double            m_hvnBuffer[];
   double            m_lvnBuffer[];
   double            m_pocValues[10];
   double            m_vahValues[10];
   double            m_valValues[10];
   VolumeProfileData m_current;
   datetime          m_lastUpdate;
   
public:
   CVPHelper();
   ~CVPHelper();
   
   bool              Init(string symbol = "");
   void              Deinit();
   bool              Refresh();
   
   double            GetPOC();
   double            GetVAH();
   double            GetVAL();
   double            GetTotalVolume();
   datetime          GetProfileTime();
   
   bool              IsPriceInValueArea(double price);
   bool              IsPriceAboveVAH(double price);
   bool              IsPriceBelowVAL(double price);
   bool              IsPOCZone(double price, double tolerancePts = 0);
   
   double            GetDistanceToPOC(double price);
   double            GetDistanceToVAH(double price);
   double            GetDistanceToVAL(double price);
   
   int               GetProfileZone(double price);
   bool              IsValid() { return m_current.isValid; }
   
   bool              CheckForFilter(string &reason);
};

CVPHelper::CVPHelper() : m_handle(INVALID_HANDLE), m_lastUpdate(0)
{
   ArraySetAsSeries(m_pocBuffer, true);
   ArraySetAsSeries(m_vahBuffer, true);
   ArraySetAsSeries(m_valBuffer, true);
   ArraySetAsSeries(m_hvnBuffer, true);
   ArraySetAsSeries(m_lvnBuffer, true);
   
   m_current.pocPrice = 0;
   m_current.vahPrice = 0;
   m_current.valPrice = 0;
   m_current.totalVolume = 0;
   m_current.profileTime = 0;
   m_current.isValid = false;
}

CVPHelper::~CVPHelper()
{
   Deinit();
}

bool CVPHelper::Init(string symbol = "")
{
   Deinit();
   
   if(symbol == "")
      symbol = _Symbol;
   
   m_handle = iCustom(symbol, PERIOD_CURRENT, VP_INDICATOR_NAME);
   if(m_handle == INVALID_HANDLE)
   {
      Print("VolumeProfileHelper: Failed to load indicator for ", symbol);
      return false;
   }
   
   ArrayResize(m_pocBuffer, 10);
   ArrayResize(m_vahBuffer, 10);
   ArrayResize(m_valBuffer, 10);
   ArrayResize(m_hvnBuffer, 10);
   ArrayResize(m_lvnBuffer, 10);
   
   SetIndexBuffer(0, m_pocBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, m_vahBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, m_valBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, m_hvnBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, m_lvnBuffer, INDICATOR_DATA);
   
   return true;
}

void CVPHelper::Deinit()
{
   if(m_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
   }
   m_current.isValid = false;
}

bool CVPHelper::Refresh()
{
   if(m_handle == INVALID_HANDLE)
      return false;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - m_lastUpdate < 5)
      return m_current.isValid;
   
   int rates = CopyBuffer(m_handle, 0, 0, 10, m_pocBuffer);
   if(rates <= 0)
   {
      m_current.isValid = false;
      return false;
   }
   
   CopyBuffer(m_handle, 1, 0, 10, m_vahBuffer);
   CopyBuffer(m_handle, 2, 0, 10, m_valBuffer);
   
   m_current.pocPrice = m_pocBuffer[0];
   m_current.vahPrice = m_vahBuffer[0];
   m_current.valPrice = m_valBuffer[0];
   m_current.isValid = (m_current.pocPrice > 0);
   m_current.profileTime = currentTime;
   
   m_lastUpdate = currentTime;
   return m_current.isValid;
}

double CVPHelper::GetPOC()
{
   Refresh();
   return m_current.pocPrice;
}

double CVPHelper::GetVAH()
{
   Refresh();
   return m_current.vahPrice;
}

double CVPHelper::GetVAL()
{
   Refresh();
   return m_current.valPrice;
}

double CVPHelper::GetTotalVolume()
{
   Refresh();
   return m_current.totalVolume;
}

datetime CVPHelper::GetProfileTime()
{
   Refresh();
   return m_current.profileTime;
}

bool CVPHelper::IsPriceInValueArea(double price)
{
   Refresh();
   if(!m_current.isValid)
      return false;
   return (price > m_current.valPrice && price < m_current.vahPrice);
}

bool CVPHelper::IsPriceAboveVAH(double price)
{
   Refresh();
   return m_current.isValid && (price >= m_current.vahPrice);
}

bool CVPHelper::IsPriceBelowVAL(double price)
{
   Refresh();
   return m_current.isValid && (price <= m_current.valPrice);
}

bool CVPHelper::IsPOCZone(double price, double tolerancePts = 0)
{
   Refresh();
   if(!m_current.isValid)
      return false;
   
   if(tolerancePts <= 0)
      tolerancePts = 50 * _Point;
   
   return MathAbs(price - m_current.pocPrice) <= tolerancePts;
}

double CVPHelper::GetDistanceToPOC(double price)
{
   Refresh();
   if(!m_current.isValid)
      return 0;
   return MathAbs(price - m_current.pocPrice) / _Point;
}

double CVPHelper::GetDistanceToVAH(double price)
{
   Refresh();
   if(!m_current.isValid)
      return 0;
   return MathAbs(price - m_current.vahPrice) / _Point;
}

double CVPHelper::GetDistanceToVAL(double price)
{
   Refresh();
   if(!m_current.isValid)
      return 0;
   return MathAbs(price - m_current.valPrice) / _Point;
}

int CVPHelper::GetProfileZone(double price)
{
   Refresh();
   if(!m_current.isValid)
      return -1;
   
   if(MathAbs(price - m_current.pocPrice) < 100 * _Point)
      return 0;
   
   if(price >= m_current.vahPrice)
      return 1;
   
   if(price <= m_current.valPrice)
      return 2;
   
   return 3;
}

bool CVPHelper::CheckForFilter(string &reason)
{
   reason = "";
   return false;
}

#endif
