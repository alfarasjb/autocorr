


#ifdef __MQL4__
#include "trade_mt4.mqh"
#endif 

#ifdef __MQL5__
#include "trade_mt5.mqh"
#endif
#include <B63/Generic.mqh>
#include <B63/CExport.mqh>
#include <MAIN/Loader.mqh> 
#include "forex_factory.mqh"


CAutoCorrTrade             autocorr_trade;
CExport                    export_hist("autocorrelation");
CNewsEvents                news_events();
CCalendarHistoryLoader     calendar_loader;


int OnInit()
  {
//---
   autocorr_trade.SetRiskProfile();
   autocorr_trade.InitializeSymbolProperties();
   autocorr_trade.InitializeTradeOpsProperties();
   
   
   int num_news_data    = news_events.FetchData();
   
   autocorr_trade.logger(StringFormat("%i news events added. %i events today.", num_news_data, news_events.NumNewsToday()), __FUNCTION__);
   autocorr_trade.logger(StringFormat("High Impact News Today: %s", (string) news_events.HighImpactNewsToday()), __FUNCTION__);
   autocorr_trade.logger(StringFormat("Num High Impact News Today: %i", news_events.GetNewsSymbolToday()), __FUNCTION__);
   
   autocorr_trade.SetNextTradeWindow();
   
   int events_in_window = news_events.GetHighImpactNewsInEntryWindow(TRADE_QUEUE.curr_trade_open, TRADE_QUEUE.curr_trade_close);
   
   autocorr_trade.logger(StringFormat("Events In Window: %i", news_events.NumNewsInWindow()), __FUNCTION__);
   
   TerminalStatus();
   
   EventsInWindow();
   
   return(INIT_SUCCEEDED);
   
  }
  
  
  
void OnDeinit(const int reason)
  {
//---
   if (IsTesting()) export_hist.ExportAccountHistory();
   ObjectsDeleteAll(0, 0, -1);
   
  }
  
  
void OnTick() {
/*
LOOP FUNCTIONS
   New candle
   correct period 
   minimum equity 
   valid trade open 
   
   news 
   
   closing
   set next trade window
   check order deadline 
   
   running positions
   
   is new day
   
   update accounts
*/
   if (IsNewCandle() && autocorr_trade.CorrectPeriod() && autocorr_trade.MinimumEquity()) {
      bool ValidTradeOpen  = autocorr_trade.ValidTradeOpen();
      if (ValidTradeOpen) {
      
         bool     EventsInEntryWindow     = news_events.HighImpactNewsInEntryWindow();
         bool     BacktestEventsInWindow  = InpTradeOnNews ? false : calendar_loader.EventInWindow(TRADE_QUEUE.curr_trade_open, TRADE_QUEUE.curr_trade_close);
      
         autocorr_trade.logger(StringFormat("Events In Entry Window: %s, Backtest Events In Window: %s", 
            (string)EventsInEntryWindow, 
            (string)BacktestEventsInWindow), __FUNCTION__, false, InpDebugLogging);
         
         if (!BacktestEventsInWindow && !EventsInEntryWindow) {
            int order_send_result      = autocorr_trade.SendOrder();
            
         }
      }
      
      else {
         bool ValidTradeClose = autocorr_trade.ValidTradeClose();
         if (ValidTradeClose) {
            autocorr_trade.CloseOrder();
         }
      }
      autocorr_trade.SetNextTradeWindow();
      autocorr_trade.CheckOrderDeadline();
      int   positions_added   = autocorr_trade.OrdersEA();
      
      if (autocorr_trade.IsTradeWindow()) {
         autocorr_trade.logger(StringFormat("Checked Order Pool. %i Position/s Found.", positions_added), __FUNCTION__);
         autocorr_trade.logger(StringFormat("%i Order/s in Active List", autocorr_trade.NumActivePositions()), __FUNCTION__);
      }
      
      if (autocorr_trade.IsNewDay()) { 
         autocorr_trade.ClearOrdersToday();
         // REBALANCE HERE 
         // ADD: TRADING WINDOW START HOUR
      }
      if (autocorr_trade.PreEntry()) {
         if (IsTesting()) {
            if (calendar_loader.IsNewYear()) calendar_loader.LoadCSV(HIGH);
            
            int   num_news_loaded      = calendar_loader.LoadDatesToday(HIGH);
            
            autocorr_trade.logger(StringFormat("NEWS LOADED: %i", num_news_loaded), __FUNCTION__, false, InpDebugLogging);
            calendar_loader.UpdateToday();
         }
         
         TerminalStatus();
         
         LotsStatus();
         
         RefreshNews();
         
         EventsSymbolToday();
         
         EventsInWindow();
      }
   }
}
  
  
// ========== MISC ========== // 

void     LotsStatus() {
   
   autocorr_trade.logger(StringFormat("Pre-Entry \n\nRisk: %.2f \nLot: %.2f \nMax Lot: %.2f",
      autocorr_trade.ValueAtRisk(),
      autocorr_trade.CalcLot(),
      InpMaxLot), __FUNCTION__, true, InpDebugLogging);

}

void     TerminalStatus() {

   autocorr_trade.logger(StringFormat(
      "Terminal Status \n\nTrading: %s \nExpert: %s \nConnection: %s",
      IsTradeAllowed() ? "Enabled" : "Disabled", 
      IsExpertEnabled() ? "Enabled" : "Disabled",
      IsConnected() ? "Connected" : "Not Connected"),
      __FUNCTION__, true, InpDebugLogging);
}

void     RefreshNews() {

   int   num_news_data = news_events.FetchData();
   autocorr_trade.logger(StringFormat("%i news events added. %i events today.", num_news_data, news_events.NumNewsToday()), __FUNCTION__);

}

void     EventsSymbolToday() {
   
   autocorr_trade.logger(StringFormat("High Impact News Today: %s \nNum News Today: %i", 
      (string)news_events.HighImpactNewsToday(),
      news_events.GetNewsSymbolToday()), __FUNCTION__, false, InpDebugLogging);

}

void     EventsInWindow() {

   int   events_in_window  = news_events.GetHighImpactNewsInEntryWindow(TRADE_QUEUE.curr_trade_open, TRADE_QUEUE.curr_trade_close);
   
   autocorr_trade.logger(StringFormat("Entry Window: %s, Num Events: %i",
      TimeToString(TRADE_QUEUE.curr_trade_open),
      TimeToString(TRADE_QUEUE.curr_trade_close),
      events_in_window), __FUNCTION__, true, InpDebugLogging);

}