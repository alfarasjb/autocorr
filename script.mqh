


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
   autocorr_trade.ReBalance();
   
   int num_news_data    = news_events.FetchData();
   
   autocorr_trade.logger(StringFormat("%i news events added. %i events today.", num_news_data, news_events.NumNewsToday()), __FUNCTION__);
   autocorr_trade.logger(StringFormat("High Impact News Today: %s", (string) news_events.HighImpactNewsToday()), __FUNCTION__);
   autocorr_trade.logger(StringFormat("Num High Impact News Today: %i", news_events.GetNewsSymbolToday()), __FUNCTION__);
   
   autocorr_trade.SetNextTradeWindow();
   
   int events_in_window = news_events.GetHighImpactNewsInEntryWindow(TRADE_QUEUE.curr_trade_open, TRADE_QUEUE.curr_trade_close);
   
   autocorr_trade.logger(StringFormat("Num Events In Window: %i, Any: %s", news_events.NumNewsInWindow(), (string) news_events.HighImpactNewsInEntryWindow()), __FUNCTION__);
   
   TerminalStatus();
   
   EventsInWindow();
   
   autocorr_trade.CheckOrderDeadline();
   autocorr_trade.OrdersEA();
   if (autocorr_trade.ValidTradeOpen() && !news_events.HighImpactNewsInEntryWindow())  autocorr_trade.Stage();
   ShowComments();
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
            int order_send_result      = autocorr_trade.Stage();
            
         }
      }
      
      else {
         autocorr_trade.ManageLayers();
         //bool ValidTradeClose = autocorr_trade.ValidTradeClose();
         //if (ValidTradeClose) {
         //   autocorr_trade.CloseOrder();
         //}
      }
      autocorr_trade.SetNextTradeWindow();
      autocorr_trade.CheckOrderDeadline();
      int   positions_added   = autocorr_trade.OrdersEA();
      
      if (autocorr_trade.IsTradeWindow()) {
         autocorr_trade.logger(StringFormat("Checked Order Pool. %i Position/s Found.", positions_added), __FUNCTION__, false, InpDebugLogging);
         autocorr_trade.logger(StringFormat("%i Order/s in Active List", autocorr_trade.NumActivePositions()), __FUNCTION__, false, InpDebugLogging);
      }
      
      if (autocorr_trade.IsNewDay()) { 
         autocorr_trade.ClearOrdersToday();
         autocorr_trade.CloseOrder();
         //autocorr_trade.Close
         // REBALANCE HERE 
         // ADD: TRADING WINDOW START HOUR
         autocorr_trade.ReBalance();
         
      }
      if (autocorr_trade.PreEntry()) {
         autocorr_trade.ReBalance();
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
      ShowComments();
   }
   
}
  
  
// ========== MISC ========== // 

void     ShowComments() {

   Comment(
      StringFormat("Previous Day Close:      %f\n", UTIL_PREVIOUS_DAY_CLOSE()),
      StringFormat("Previous Day Open:       %f\n", UTIL_PREVIOUS_DAY_OPEN()),
      StringFormat("Direction Today:         %s\n\n", EnumToString(autocorr_trade.TradeDirection())),
      StringFormat("Day Start Balance:       %.2f\n", autocorr_trade.DAY_START_BALANCE()),
      StringFormat("Day Volume:              %.2f\n", autocorr_trade.DAY_VOLUME_ALLOCATION()),
      StringFormat("VAR:                     %.2f\n", autocorr_trade.ValueAtRisk()),
      StringFormat("Day Running PL:          %.2f\n\n", autocorr_trade.PLToday()),
      StringFormat("Num Active Positions:    %i\n", autocorr_trade.NumActivePositions()),
      StringFormat("Trades Today:            %i\n\n", TRADES_ACTIVE.orders_today),
      StringFormat("Trade Open:              %s\n", TimeToString(TRADE_QUEUE.curr_trade_open)),
      StringFormat("Trade Close:             %s\n\n", TimeToString(TRADE_QUEUE.curr_trade_close)),
      StringFormat("Tick Value:              %.5f\n", autocorr_trade.TICK_VALUE()),
      StringFormat("Trade Diff Ticks:        %.2f\n", autocorr_trade.TradeDiffPoints()),
      StringFormat("Trade Diff:              %.5f", autocorr_trade.TradeDiff())
      
   
   );

}

void     LotsStatus() {
   
   autocorr_trade.logger(StringFormat("Pre-Entry \n\nRisk: %.2f \nLot: %.2f \nMax Lot: %.2f",
      autocorr_trade.ValueAtRisk(),
      autocorr_trade.DAY_VOLUME_ALLOCATION(),
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
   
   autocorr_trade.logger(StringFormat("Entry Window: %s - %s, Num Events: %i",
      TimeToString(TRADE_QUEUE.curr_trade_open),
      TimeToString(TRADE_QUEUE.curr_trade_close),
      events_in_window), __FUNCTION__, true, InpDebugLogging);

}