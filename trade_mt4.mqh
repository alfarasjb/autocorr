#include "definition.mqh"
#include <MAIN/TradeOps.mqh>
class CAutoCorrTrade : CTradeOps {
   
   protected:
   private:
   public: 
      // ACCOUNT PROPERTIES
      double         ACCOUNT_CUTOFF;
   
      // SYMBOL PROPERTIES
      double         tick_value, trade_points, contract_size;
      int            digits;
      
      
      CAutoCorrTrade(); 
      ~CAutoCorrTrade() {};
      
      // INIT 
      void           SetRiskProfile(); 
      void           InitializeTradeOpsProperties();
      void           InitializeSymbolProperties();
      void           InitializeAccounts();
      double         CalcLot();
      
      double         TICK_VALUE()      { return tick_value; }
      double         TRADE_POINTS()    { return trade_points; }
      int            DIGITS()          { return digits; }
      double         CONTRACT()        { return contract_size; }
   
      // MAIN 
      int            SendOrder();
      int            SendMarketOrder();
      int            SendPendingOrder();
      int            SendSplitOrder();
      int            CloseOrder();
      double         VolumeSplitScaleFactor(ENUM_ORDER_SEND_METHOD);
      bool           CorrectPeriod();
      bool           MinimumEquity();
      bool           ValidTradeOpen();
      bool           ValidTradeClose();
      double         PreviousDayTradeDiff();
      bool           PreEntry();
      void           CheckOrderDeadline();
      int            OrdersEA();
      void           SetTradeWindow(datetime trade_datetime);
      
      
      double         ValueAtRisk();
      double         TradeDiff();
      double         TradeDiffPoints();
   
      // LOGIC
      ENUM_DIRECTION    TradeDirection();
      ENUM_ORDER_TYPE   TradeOrderType();
      
      TradeParams       TradeParamsLong(ENUM_ORDER_SEND_METHOD method);
      TradeParams       TradeParamsShort(ENUM_ORDER_SEND_METHOD method);
      
      
      // TRADE QUEUE 
      void           SetNextTradeWindow();
      datetime       WindowCloseTime(datetime window_open_time, int candle_intervals);
      bool           IsTradeWindow();
      bool           IsNewDay(); 
      
      // TRADES ACTIVE 
      void           AddOrderToday();
      void           ClearOrdersToday();
      void           AppendActivePosition(ActivePosition &active_position);
      int            NumActivePositions();
      bool           TradeInPool(int ticket);
      int            RemoveTradeFromPool(int ticket);
      void           ClearPositions();
      
      // UTILITIES
      int            logger(string message, string function, bool notify = false, bool debug = false);
      void           errors(string error_message);
      bool           notification(string message);
      
};


CAutoCorrTrade::CAutoCorrTrade(void) {

   InitializeSymbolProperties();
   InitializeTradeOpsProperties();
   
}  


void              CAutoCorrTrade::InitializeTradeOpsProperties(void) {
   
   SYMBOL(Symbol());
   MAGIC(InpMagic);

}

void              CAutoCorrTrade::InitializeSymbolProperties(void) {

   tick_value        = UTIL_TICK_VAL();
   trade_points      = UTIL_TRADE_PTS();
   digits            = UTIL_SYMBOL_DIGITS();
   contract_size     = UTIL_SYMBOL_CONTRACT_SIZE();
   
}

void              CAutoCorrTrade::SetRiskProfile(void) {

   RISK_PROFILE.RP_amount              = (InpRPRiskPercent / 100) * InpRPDeposit;
   RISK_PROFILE.RP_lot                 = InpRPLot; 
   RISK_PROFILE.RP_half_life           = InpRPHalfLife; 
   RISK_PROFILE.RP_order_send_method   = InpRPOrderSendMethod;
   RISK_PROFILE.RP_timeframe           = InpRPTimeframe;   
   RISK_PROFILE.RP_market_split        = InpRPMarketSplit;
   
}

void              CAutoCorrTrade::SetTradeWindow(datetime trade_datetime) {

   MqlDateTime trade_close_struct;
   datetime next  = TimeCurrent() + (UTIL_INTERVAL_CURRENT() * RISK_PROFILE.RP_half_life);
   TimeToStruct(next, trade_close_struct);
   trade_close_struct.sec     = 0;
   
   TRADES_ACTIVE.trade_open_datetime      = trade_datetime;
   TRADES_ACTIVE.trade_close_datetime     = StructToTime(trade_close_struct);
}

int               CAutoCorrTrade::OrdersEA(void) {

   int open_positions   =  PosTotal();
   
   int ea_positions     = 0;
   int trades_found     = 0;
   
   for (int i = 0; i < open_positions; i++) {
      if (OP_TradeMatch(i)) {
         trades_found++;
         int   ticket   = PosTicket();
         if (TradeInPool(ticket)) continue;
         
         ActivePosition pos;
         pos.pos_open_datetime   = PosOpenTime();
         pos.pos_ticket          = ticket;
         pos.pos_deadline        = pos.pos_open_datetime + (UTIL_INTERVAL_CURRENT() * RISK_PROFILE.RP_half_life);
         
         AppendActivePosition(pos);
         ea_positions++;
      }
   
   }
   if (trades_found == 0 && ea_positions == 0 && NumActivePositions() > 0) ClearPositions();
   return trades_found;
}


bool              CAutoCorrTrade::TradeInPool(int ticket) {

   int   trades_in_pool    =  NumActivePositions();
   
   for (int i = 0; i < trades_in_pool; i++) {
      if (ticket == TRADES_ACTIVE.active_positions[i].pos_ticket) return true;
   }
   return false;
}

int               CAutoCorrTrade::RemoveTradeFromPool(int ticket) {

   int   trades_in_pool    = NumActivePositions();
   ActivePosition    last_positions[];
   
   for (int i = 0; i < trades_in_pool; i++) {
      if (ticket == TRADES_ACTIVE.active_positions[i].pos_ticket) continue;
      int num_last_positions  =  ArraySize(last_positions);
      ArrayResize(last_positions, num_last_positions + 1);
      last_positions[num_last_positions]  =  TRADES_ACTIVE.active_positions[i];
   }
   ArrayFree(TRADES_ACTIVE.active_positions);
   ArrayCopy(TRADES_ACTIVE.active_positions, last_positions);
   
   return ArraySize(last_positions);
}

void              CAutoCorrTrade::ClearPositions(void) {
   
   ArrayFree(TRADES_ACTIVE.active_positions);
   ArrayResize(TRADES_ACTIVE.active_positions, 0);
   
}

void              CAutoCorrTrade::CheckOrderDeadline(void) {

   int active     = NumActivePositions();
   
   if (active == 0) return; 
   
   for (int i = 0; i < active; i++) {
      ActivePosition pos   = TRADES_ACTIVE.active_positions[i];
      if (pos.pos_deadline > TimeCurrent()) continue; 
      int c = OP_CloseTrade(pos.pos_ticket);   
      if (c) logger(StringFormat("Trade Closed: %i", PosTicket()), __FUNCTION__, true);
   }

}

void              CAutoCorrTrade::AppendActivePosition(ActivePosition &active_position) {

   int size    = ArraySize(TRADES_ACTIVE.active_positions);
   ArrayResize(TRADES_ACTIVE.active_positions, size + 1);
   TRADES_ACTIVE.active_positions[size]   = active_position;
   logger(StringFormat("Updated active positions: %i, Ticket: %i", NumActivePositions(), active_position.pos_ticket), __FUNCTION__);

}

int               CAutoCorrTrade::CloseOrder(void) {
   //Print("CLOSE: ", TimeCurrent());
   int c = OP_OrdersCloseAll();
   if (c > 0) ClearPositions();
   return 1;

}
double            CAutoCorrTrade::CalcLot(void) {
   
   double      risk_amount_scale_factor   = InpRiskAmount / RISK_PROFILE.RP_amount; 
   double      scaled_lot                 = (RISK_PROFILE.RP_lot * InpAllocation * risk_amount_scale_factor) * TICK_VALUE() * (1 / TRADE_POINTS()) * (1 / CONTRACT());
   
   scaled_lot  = scaled_lot > InpMaxLot ? InpMaxLot : scaled_lot; 
   
   double symbol_minlot    = UTIL_SYMBOL_MINLOT();
   double symbol_maxlot    = UTIL_SYMBOL_MAXLOT(); 
   
   if (scaled_lot < symbol_minlot) return symbol_minlot;
   if (scaled_lot > symbol_maxlot) return symbol_maxlot;
   
   scaled_lot     = UTIL_SYMBOL_LOTSTEP() == 1 ? (int)scaled_lot : UTIL_NORM_VALUE(scaled_lot);
   
   return scaled_lot;
}


void              CAutoCorrTrade::SetNextTradeWindow(void) {

   MqlDateTime current; 
   TimeToStruct(TimeCurrent(), current);
   
   current.hour      = InpEntryHour;
   current.min       = InpEntryMin;
   current.sec       = 0;
   
   datetime entry    = StructToTime(current);
   
   TRADE_QUEUE.curr_trade_open      = entry; 
   TRADE_QUEUE.next_trade_open      = TimeCurrent() > entry ? entry + UTIL_INTERVAL_DAY() : entry; 
   
   TRADE_QUEUE.curr_trade_close     = WindowCloseTime(TRADE_QUEUE.curr_trade_open, RISK_PROFILE.RP_half_life);
   TRADE_QUEUE.next_trade_close     = WindowCloseTime(TRADE_QUEUE.next_trade_open, RISK_PROFILE.RP_half_life);


}

datetime          CAutoCorrTrade::WindowCloseTime(datetime window_open_time, int candle_intervals) {
   
   window_open_time = window_open_time + (UTIL_INTERVAL_CURRENT() * candle_intervals);
   return window_open_time;
   
}

bool              CAutoCorrTrade::IsTradeWindow(void) {

   if (TimeCurrent() >= TRADE_QUEUE.curr_trade_open && TimeCurrent() < TRADE_QUEUE.curr_trade_close) return true;
   return false;

}

bool              CAutoCorrTrade::IsNewDay(void) {

   if (TimeCurrent() < TRADE_QUEUE.curr_trade_open) return true;
   return false;
   
}

TradeParams       CAutoCorrTrade::TradeParamsLong(ENUM_ORDER_SEND_METHOD method) {
   
   TradeParams PARAMS; 
   PARAMS.entry_price   = method == MODE_MARKET ? UTIL_PRICE_ASK() : method == MODE_PENDING ? UTIL_LAST_CANDLE_OPEN() : 0;
   PARAMS.sl_price      = PARAMS.entry_price - (RISK_PROFILE.RP_amount / (RISK_PROFILE.RP_lot * TICK_VALUE() * (1 / TRADE_POINTS())));
   PARAMS.tp_price      = 0;
   PARAMS.volume        = CalcLot();
   
   return PARAMS;


}
TradeParams       CAutoCorrTrade::TradeParamsShort(ENUM_ORDER_SEND_METHOD method) {
   
   TradeParams PARAMS;
   PARAMS.entry_price   = method == MODE_MARKET ? UTIL_PRICE_BID() : method == MODE_PENDING ? UTIL_PRICE_ASK() : 0; 
   PARAMS.sl_price      = PARAMS.entry_price + ((RISK_PROFILE.RP_amount) / (RISK_PROFILE.RP_lot * TICK_VALUE() * (1 / TRADE_POINTS())));
   PARAMS.tp_price      = 0;
   PARAMS.volume        = CalcLot();
   Print("Bid: %f, Open: %f", UTIL_PRICE_BID(), UTIL_LAST_CANDLE_OPEN());
   //PrintFormat("RP LOT: %f, Tick Val: %f, Trade Points: %f", RISK_PROFILE.RP_lot, TICK_VALUE(), TRADE_POINTS());
   return PARAMS;
   
}

ENUM_DIRECTION    CAutoCorrTrade::TradeDirection(void) {
   
   if (PreviousDayTradeDiff() > 0) return LONG; 
   return SHORT;
}


int               CAutoCorrTrade::SendOrder(void) {
   
   switch(RISK_PROFILE.RP_order_send_method) {
      case MODE_MARKET:       return SendMarketOrder();
      case MODE_PENDING:      return SendPendingOrder();
      case MODE_SPLIT:        return SendSplitOrder();
      default:                break;
   }
   return 0;
}

int               CAutoCorrTrade::SendMarketOrder(void) {
   
   
   ENUM_DIRECTION    trade_direction   = TradeDirection();
   ENUM_ORDER_TYPE   order_type;
   TradeParams       PARAMS;
   switch(trade_direction) {
      case LONG: 
         order_type  = ORDER_TYPE_BUY;
         PARAMS      = TradeParamsLong(MODE_MARKET);
         break;
      case SHORT:
         order_type  = ORDER_TYPE_SELL;
         PARAMS      = TradeParamsShort(MODE_MARKET);
         break;
         
      default:
         // ORDER FAILED 
         return -1; 
   }
   
   //double volume  = RISK_PROFILE.RP_order_send_method == MODE_SPLIT ? PARAMS.volume * 0.5 : PARAMS.volume;
   double volume  = PARAMS.volume * VolumeSplitScaleFactor(MODE_MARKET);
   
   int ticket     = OP_OrderOpen(Symbol(), order_type, volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price, EA_ID, InpMagic);
   
   if (ticket == -1) {
      logger(StringFormat("ORDER SEND FAILED. ERROR: %i", GetLastError()), __FUNCTION__, true);
      return -1; 
   }
   
   SetTradeWindow(TimeCurrent());
   
   ActivePosition    pos;
   pos.pos_open_datetime   =  TRADES_ACTIVE.trade_open_datetime;
   pos.pos_deadline        =  TRADES_ACTIVE.trade_close_datetime;
   pos.pos_ticket          =  ticket;
   AppendActivePosition(pos);
   
   AddOrderToday();
   return ticket; 
}
int               CAutoCorrTrade::SendPendingOrder(void) {

   ENUM_DIRECTION    trade_direction   = TradeDirection();
   ENUM_ORDER_TYPE   order_type;
   TradeParams       PARAMS; 
   
   switch(trade_direction) {
      case LONG:
         order_type  = ORDER_TYPE_BUY_LIMIT;
         PARAMS      = TradeParamsLong(MODE_PENDING);
         break;
      case SHORT: 
         order_type  = ORDER_TYPE_SELL_LIMIT;
         PARAMS      = TradeParamsShort(MODE_PENDING);
         break;
      default:
         // ORDER FAILED 
         return -1;
   }
   
   //double volume  = RISK_PROFILE.RP_order_send_method == MODE_SPLIT ? PARAMS.volume * 0.5 : CalcLot();
   double volume  = PARAMS.volume * VolumeSplitScaleFactor(MODE_PENDING);
   
   int ticket  = OP_OrderOpen(Symbol(), order_type, volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price, EA_ID, InpMagic);
   if (ticket == -1) {
      logger(StringFormat("ORDER SEND FAILED. ERROR: %i", GetLastError()), __FUNCTION__, true);
      return -1;
   }
   
   SetTradeWindow(TimeCurrent());
   
   ActivePosition    pos;
   pos.pos_open_datetime   =  TRADES_ACTIVE.trade_open_datetime;
   pos.pos_deadline        =  TRADES_ACTIVE.trade_close_datetime;
   pos.pos_ticket          =  ticket;
   AppendActivePosition(pos);
   
   AddOrderToday();
   return ticket;
   
}
int               CAutoCorrTrade::SendSplitOrder(void) {
   int market_ticket    = SendMarketOrder();
   int pending_ticket   = SendPendingOrder();
   
   if (market_ticket > 1 && pending_ticket > 1) return 1;
   return -1;  
}

int               CAutoCorrTrade::logger(string message,string function,bool notify=false,bool debug=false) {
   if (!InpTerminalMsg && !debug) return -1;
   
   string mode    = debug ? "DEBUGGER" : "LOGGER";
   string func    = InpDebugLogging ? StringFormat(" - %s", function) : "";
   
   PrintFormat("%s %s: %s", mode, func, message);
   
   if (notify) notification(message);
   return 1;
}

bool              CAutoCorrTrade::notification(string message) {
   
   if (!InpPushNotifs) return false;
   if (IsTesting()) return false;
   
   bool n   = SendNotification(message);
   
   if (!n)  logger(StringFormat("Failed to send notification. Cose: %i", GetLastError()), __FUNCTION__);
   return n;
} 


double            CAutoCorrTrade::VolumeSplitScaleFactor(ENUM_ORDER_SEND_METHOD method) {

   if (RISK_PROFILE.RP_order_send_method != MODE_SPLIT) return 1; 
   
   switch(method) {
      case MODE_MARKET:    return RISK_PROFILE.RP_market_split; 
      case MODE_PENDING:   return 1 - RISK_PROFILE.RP_market_split;
      default: break; 
   }
   return 0;

}


bool           CAutoCorrTrade::CorrectPeriod(void) {

   if (Period() == RISK_PROFILE.RP_timeframe) return true; 
   errors(StringFormat("INVALID TIMEFRAME. USE: %s", EnumToString(RISK_PROFILE.RP_timeframe)));
   return false;

}


bool           CAutoCorrTrade::MinimumEquity(void) {
   
   double account_equity   =  UTIL_ACCOUNT_EQUITY();
   if (account_equity < ACCOUNT_CUTOFF) {
      logger(StringFormat("TRADING DISABLED. Account Equity is below Minimum Trading Requirement. Current Equity: %.2f, Required: %.2f", account_equity, ACCOUNT_CUTOFF), __FUNCTION__);
      return false;
   }
   return true;

}


bool           CAutoCorrTrade::ValidTradeOpen(void) {
   
   if (IsTradeWindow() && OrdersTotal() == 0 && TRADES_ACTIVE.orders_today == 0) return true;
   return false;
   
}


bool           CAutoCorrTrade::ValidTradeClose(void) {

   if (TimeCurrent() >= TRADE_QUEUE.curr_trade_close) return true;
   return false;

}

bool           CAutoCorrTrade::PreEntry(void) {

   datetime prev_candle    = TRADE_QUEUE.curr_trade_open - UTIL_INTERVAL_CURRENT(); 
   
   if (TimeCurrent() >= prev_candle && TimeCurrent() < TRADE_QUEUE.curr_trade_open) return true; 
   return false;

}


int            CAutoCorrTrade::NumActivePositions(void)        { return ArraySize(TRADES_ACTIVE.active_positions); }

double         CAutoCorrTrade::PreviousDayTradeDiff(void)      { return UTIL_PREVIOUS_DAY_CLOSE() - UTIL_PREVIOUS_DAY_OPEN();}
void           CAutoCorrTrade::errors(string error_message)    { Print("ERROR: ", error_message); }


void           CAutoCorrTrade::AddOrderToday(void)             { TRADES_ACTIVE.orders_today++; }
void           CAutoCorrTrade::ClearOrdersToday(void)          { TRADES_ACTIVE.orders_today = 0;}

double         CAutoCorrTrade::TradeDiff(void)                 { return ((RISK_PROFILE.RP_amount) / (RISK_PROFILE.RP_lot * TICK_VALUE() * (1 / TRADE_POINTS()))); }
double         CAutoCorrTrade::TradeDiffPoints(void)           { return ((RISK_PROFILE.RP_amount) / (RISK_PROFILE.RP_lot * TICK_VALUE())); }
double         CAutoCorrTrade::ValueAtRisk(void)               { return CalcLot() * TradeDiffPoints() * TICK_VALUE(); }