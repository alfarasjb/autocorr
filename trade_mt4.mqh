#include "definition.mqh"
#include "profiles.mqh"
#include <MAIN/TradeOps.mqh>
class CAutoCorrTrade : public CTradeOps {
   
   protected:
   private:
      // REBALANCE
      double         day_start_balance, day_volume_allocation;
      int            entry_hour, entry_minute;
   public: 
      // ACCOUNT PROPERTIES
      double         ACCOUNT_CUTOFF, ACCOUNT_BASE_RISK_AMOUNT; 
   
      // SYMBOL PROPERTIES
      double         tick_value, trade_points, contract_size;
      int            digits;
      
      // PROFILE
      TradeProfile   LoadedProfile;
      
      CAutoCorrTrade(); 
      ~CAutoCorrTrade();
      
      // INIT 
      void           SetRiskProfile(); 
      TradeProfile   InitializeProfile();
      void           InitializeTradeOpsProperties(int magic);
      void           InitializeSymbolProperties();
      void           InitializeAccounts();
      double         CalcLot();
      void           ReBalance();
      
      double         TICK_VALUE()      { return tick_value; }
      double         TRADE_POINTS()    { return trade_points; }
      int            DIGITS()          { return digits; }
      double         CONTRACT()        { return contract_size; }
      
      double         DAY_START_BALANCE()                    { return day_start_balance; }
      double         DAY_VOLUME_ALLOCATION()                { return day_volume_allocation; }
         
      void           DAY_START_BALANCE(double balance)      { day_start_balance  =  balance; }
      void           DAY_VOLUME_ALLOCATION(double volume)   { day_volume_allocation = volume; }
      
      int            ENTRY_HOUR()               { return entry_hour; }
      int            ENTRY_MINUTE()             { return entry_minute; }
      
      void           ENTRY_HOUR(int hour)       { entry_hour = hour; }
      void           ENTRY_MINUTE(int minute)   { entry_minute = minute; }
      
      void           ACCOUNT_RISK(double amount)            { ACCOUNT_BASE_RISK_AMOUNT = amount; }
      double         ACCOUNT_RISK()                         { return ACCOUNT_BASE_RISK_AMOUNT; }
      
   
      // MAIN 
      int            SendOrder(TradeParams &params);
      int            SendMarketOrder(TradeParams &PARAMS);
      int            SendPendingOrder(TradeParams &PARAMS);
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
      double         PLToday();
      double         EntryCandleOpen();
      int            ShiftToEntry();
      int            Stage();
      int            ExecuteLayer();
      TradeParams    SetTradeParameters(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer);
      ENUM_LAYER     LayerType(string trade_comment);
      int            ManageLayers();
      int            CloseSecondaryLayers();
      int            ClosePrimaryLayers();
      int            UpdateActiveTrades(ActivePosition &pool[]);
      int            TrailStop(ActivePosition &pool[]);
      bool           InvalidPriceForPendingOrder(TradeParams &PARAMS);
      bool           TradeIsPending(int ticket);
      bool           IsOptimalSpread();
      
      double         ValueAtRisk();
      double         TradeDiff();
      double         TradeDiffPoints();
      double         TradePoints(int ticks);
   
      // LOGIC
      ENUM_DIRECTION    TradeDirection();
      ENUM_ORDER_TYPE   TradeOrderType();
      
      TradeParams       TradeParamsLong(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer);
      TradeParams       TradeParamsShort(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer);
      
      
      // TRADE QUEUE 
      void           SetNextTradeWindow();
      datetime       WindowCloseTime(datetime window_open_time, int candle_intervals);
      bool           IsTradeWindow();
      bool           IsNewDay(); 
      
      // TRADES ACTIVE 
      void           AddOrderToday();
      void           ClearOrdersToday();
      void           AppendActivePosition(ActivePosition &position, ActivePosition &array[]);
      int            NumActivePositions();
      bool           TradeInPool(int ticket, ActivePosition &pool[]);
      int            RemoveTradeFromPool(int ticket, ActivePosition &pool[]);
      void           ClearPositions();
      bool           TradeIsOpen(int ticket);
      int            NumPrimaryLayers();
      int            NumSecondaryLayers();
      int            UpdateLayers();
      
      
      // UTILITIES
      int            logger(string message, string function, bool notify = false, bool debug = false);
      void           errors(string error_message);
      bool           notification(string message);
      
};


CAutoCorrTrade::CAutoCorrTrade(void) {
   
   InitializeSymbolProperties();
   
}  

CAutoCorrTrade::~CAutoCorrTrade(void) {
   ClearPositions();
   ClearOrdersToday();
}

void              CAutoCorrTrade::InitializeTradeOpsProperties(int magic) {
   
   SYMBOL(Symbol());
   MAGIC(magic);

}

TradeProfile      CAutoCorrTrade::InitializeProfile(void) {
   

   CProfiles *profiles  = new CProfiles(InpProfilePath);
   
   logger(StringFormat("Importing Trade Profile from %s", profiles.FILE_PATH), __FUNCTION__);
   LoadedProfile        = profiles.BuildProfile();
   delete profiles;
   
   return LoadedProfile;
}

void              CAutoCorrTrade::InitializeSymbolProperties(void) {

   tick_value        = UTIL_TICK_VAL();
   trade_points      = UTIL_TRADE_PTS();
   digits            = UTIL_SYMBOL_DIGITS();
   contract_size     = UTIL_SYMBOL_CONTRACT_SIZE();
   
}

void              CAutoCorrTrade::SetRiskProfile(void) {
   
   int MAGIC = 0;
   TradeProfile   profile           = InitializeProfile(); 
   if (InpLoadFromFile && profile.trade_symbol == Symbol()) {
   
      RISK_PROFILE.RP_amount           = (profile.trade_risk_percent / 100) * InpRPDeposit; 
      RISK_PROFILE.RP_lot              = profile.trade_lot;
      RISK_PROFILE.RP_half_life        = profile.trade_half_life;
      //RISK_PROFILE
      MAGIC                            = profile.trade_magic;
      
      MqlDateTime profile_time; 
      TimeToStruct(profile.trade_open_time, profile_time);
      ENTRY_HOUR(profile_time.hour);
      ENTRY_MINUTE(profile_time.min);
            
   }
   else {
      if (profile.trade_symbol != Symbol()) logger(StringFormat("Invalid Profile loaded for %s", Symbol()), __FUNCTION__);
      logger(StringFormat("%s Risk Profile taken from program configuration.", Symbol()), __FUNCTION__);
      RISK_PROFILE.RP_amount              = (InpRPRiskPercent / 100) * InpRPDeposit;
      RISK_PROFILE.RP_lot                 = InpRPLot; 
      RISK_PROFILE.RP_half_life           = InpRPHalfLife; 
      
      ENTRY_HOUR(InpEntryHour);
      ENTRY_MINUTE(InpEntryMin);
   }
   
   RISK_PROFILE.RP_spread              = InpRPSpreadLimit;
   RISK_PROFILE.RP_order_send_method   = InpRPOrderSendMethod;
   RISK_PROFILE.RP_timeframe           = InpRPTimeframe;   
   RISK_PROFILE.RP_market_split        = InpRPMarketSplit;
   RISK_PROFILE.RP_trade_logic         = InpRPTradeLogic;
   RISK_PROFILE.RP_positions           = InpRPPositions;
   RISK_PROFILE.RP_layer_orders        = InpRPLayerOrders;
   
   MAGIC = MAGIC == 0 ? InpMagic : MAGIC;
   //int MAGIC   = InpLoadFromFile ? profile.trade_magic != 0 ? profile.trade_magic : InpMagic : InpMagic;
   logger(StringFormat("RP Amount: %.2f RP Lot: %.2f RP Half Life: %i",
      RISK_PROFILE.RP_amount, 
      RISK_PROFILE.RP_lot,
      RISK_PROFILE.RP_half_life), __FUNCTION__);
      
     
   InitializeTradeOpsProperties(MAGIC); 
   ACCOUNT_RISK((InpAccountRiskPct / 100) * InpAccountDeposit);
}

void              CAutoCorrTrade::SetTradeWindow(datetime trade_datetime) {

   MqlDateTime trade_close_struct;
   datetime next  = TimeCurrent() + (UTIL_INTERVAL_CURRENT() * RISK_PROFILE.RP_half_life);
   TimeToStruct(next, trade_close_struct);
   trade_close_struct.sec     = 0;
   
   TRADES_ACTIVE.trade_open_datetime      = trade_datetime;
   TRADES_ACTIVE.trade_close_datetime     = StructToTime(trade_close_struct);
}

bool              CAutoCorrTrade::IsOptimalSpread(void) {
   
   if (UTIL_MARKET_SPREAD() > RISK_PROFILE.RP_spread) return false; 
   logger(StringFormat("Spread is optimal. Sending market order. Bid: %f, Ask: %f", 
      UTIL_PRICE_BID(), 
      UTIL_PRICE_ASK()), __FUNCTION__); 
   return true;

}

double            CAutoCorrTrade::PLToday(void) {

   // iterate through history, check order close date. if today, add to current pl 
   
   int      hist_total     = PosHistTotal(); 
   double   pl             = 0;
   for (int i = 0; i < hist_total; i++) {
      int s = OP_HistorySelectByIndex(i);
      if (!UTIL_DATE_MATCH(UTIL_DATE_TODAY(), PosCloseTime())) continue; 
      pl += PosProfit();
   }
   return pl;
}


void              CAutoCorrTrade::ReBalance(void) {

   // CALC LOT ALLOCATION FOR THE DAY
   double   pl_today    = PLToday();
   
   DAY_START_BALANCE(UTIL_ACCOUNT_BALANCE() - pl_today);
   DAY_VOLUME_ALLOCATION(CalcLot());
   
   ENUM_DIRECTION direction_today   = TradeDirection();
   
   if (PreEntry()) {
      logger(StringFormat("Day Start Balance: %f, Day Volume: %f, Day Running PL: %f", 
         DAY_START_BALANCE(), 
         DAY_VOLUME_ALLOCATION(), 
         pl_today), __FUNCTION__, false, InpDebugLogging);
      
   
      logger(StringFormat("Previous Day Close: %f, Previous Day Open: %f, Direction Today: %s", 
         UTIL_PREVIOUS_DAY_CLOSE(), 
         UTIL_PREVIOUS_DAY_OPEN(), 
         EnumToString(direction_today)), __FUNCTION__, false, InpDebugLogging);
   }
}

int               CAutoCorrTrade::ManageLayers(void) {

   int closed_secondary = 0;
   int closed_primary = 0;
   switch(InpLayerManagement) {
      case MODE_SECURE:
         // close secondary layers in profit
         // close primary layers at deadline 
         closed_secondary  = CloseSecondaryLayers(); 
         closed_primary    = ClosePrimaryLayers(); // closes primary layers at deadline 
         break;
      case MODE_RUNNER:
         // close secondary on deadline only
         if (TimeCurrent() >= TRADES_ACTIVE.trade_close_datetime) {
            closed_secondary = CloseSecondaryLayers(); 
            logger(StringFormat("%i Trades Modified", TrailStop(TRADES_ACTIVE.primary_layers)), __FUNCTION__);
         }
         break;
      default:
         break;
   }
   UpdateActiveTrades(TRADES_ACTIVE.active_positions);
   UpdateActiveTrades(TRADES_ACTIVE.primary_layers);
   UpdateActiveTrades(TRADES_ACTIVE.secondary_layers);
   return 0; 

}


bool              CAutoCorrTrade::TradeIsPending(int ticket) {
   
   int s    = OP_OrderSelectByTicket(ticket);
   if (PosOrderType() == ORDER_TYPE_BUY || PosOrderType() == ORDER_TYPE_SELL) return false;
   return true;
   
}

int               CAutoCorrTrade::CloseSecondaryLayers(void) {
   
   int secondary_layers = NumSecondaryLayers(); 
   int closed = 0;
   for (int i = 0; i < secondary_layers; i++) {
      ActivePosition pos = TRADES_ACTIVE.secondary_layers[i]; 
      int s = OP_OrderSelectByTicket(pos.pos_ticket); 
      
      // early close -> secure secondary profits
      if (PosProfit() < 0 && TimeCurrent() < TRADES_ACTIVE.trade_close_datetime) continue;
      if (TradeIsPending(pos.pos_ticket)) continue;
      int c = OP_CloseTrade(pos.pos_ticket);
      if (c) { 
         logger(StringFormat("Closed Secondary: %i.", 
            pos.pos_ticket), __FUNCTION__);
         closed++;
         
      }
      
   }
   if (closed == secondary_layers) {
      ArrayFree(TRADES_ACTIVE.secondary_layers);
      ArrayResize(TRADES_ACTIVE.secondary_layers, 0);
   }
   return closed;
}


int               CAutoCorrTrade::ClosePrimaryLayers(void) {
   
   if (TimeCurrent() < TRADES_ACTIVE.trade_close_datetime) return 0;
   
   int primary_layers   = NumPrimaryLayers(); 
   
   int closed = 0;
   
   for (int i = 0; i < primary_layers; i ++) {
      ActivePosition pos   = TRADES_ACTIVE.primary_layers[i];
      if (!TradeIsOpen(pos.pos_ticket)) continue;
      int c = OP_CloseTrade(pos.pos_ticket);
      if (c) {
         logger(StringFormat("Closed Primary: %i", pos.pos_ticket), __FUNCTION__);
      }
           
   
   }
   return closed;
}

int               CAutoCorrTrade::UpdateActiveTrades(ActivePosition &pool[]) {

   int num_active    = ArraySize(pool);
   ActivePosition dummy[];
   ArrayCopy(dummy, pool);
   
   for (int i = 0; i < num_active; i++) {
      
      ActivePosition pos   = dummy[i];
      if (TradeIsOpen(pos.pos_ticket)) continue; 
      RemoveTradeFromPool(pos.pos_ticket, pool);      
   }
   return ArraySize(pool); 
}

int               CAutoCorrTrade::OrdersEA(void) {

   int open_positions   =  PosTotal();
   
   int ea_positions     = 0;
   int trades_found     = 0;
   
   for (int i = 0; i < open_positions; i++) {
      if (OP_TradeMatch(i)) {
         trades_found++;
         int   ticket   = PosTicket();
         if (TradeInPool(ticket, TRADES_ACTIVE.active_positions)) continue;
         
         ActivePosition pos;
         pos.pos_open_datetime   = PosOpenTime();
         pos.pos_ticket          = ticket;
         pos.pos_deadline        = pos.pos_open_datetime + (UTIL_INTERVAL_CURRENT() * RISK_PROFILE.RP_half_life);
         
         AppendActivePosition(pos, TRADES_ACTIVE.active_positions);
         ENUM_LAYER trade_layer  = LayerType(PosComment());
         
         switch (trade_layer) {
            case LAYER_PRIMARY:     AppendActivePosition(pos, TRADES_ACTIVE.primary_layers); break; 
            case LAYER_SECONDARY:   AppendActivePosition(pos, TRADES_ACTIVE.secondary_layers); break; 
            default:                break; 
         }
         ea_positions++;
      }
   
   }
   
   if (trades_found == 0 && ea_positions == 0 && NumActivePositions() > 0) ClearPositions();
   if (trades_found > 0 && NumActivePositions() > 0) UpdateLayers();
   return trades_found;
}

int               CAutoCorrTrade::UpdateLayers(void) {

   int   active   = NumActivePositions(); 
   
   for (int i = 0; i < active; i ++) {
      // iterate through each, select ticket, check comment if primary or secondary 
      ActivePosition pos      = TRADES_ACTIVE.active_positions[i];
      int s                   = OP_OrderSelectByTicket(pos.pos_ticket); 
      ENUM_LAYER trade_layer  = LayerType(PosComment()); 
      if (trade_layer == -1) continue;
      switch (trade_layer) {
         case LAYER_PRIMARY: 
            AppendActivePosition(pos, TRADES_ACTIVE.primary_layers);
            break;
         case LAYER_SECONDARY: 
            AppendActivePosition(pos, TRADES_ACTIVE.secondary_layers);
            break; 
         default: 
            break;
      }
   }
   
   //PrintFormat("ALL: %i, Num Primary: %i, Num Secondary: %i", NumActivePositions(), NumPrimaryLayers(), NumSecondaryLayers());
   return 0;
}

bool              CAutoCorrTrade::TradeInPool(int ticket, ActivePosition &pool[]) {

   int   trades_in_pool    =  ArraySize(pool);
   
   for (int i = 0; i < trades_in_pool; i++) {
      if (ticket == pool[i].pos_ticket) return true;
   }
   return false;
}

int               CAutoCorrTrade::RemoveTradeFromPool(int ticket, ActivePosition &pool[]) {

   int   trades_in_pool    = ArraySize(pool);
   ActivePosition    last_positions[]; // dummy
   
   for (int i = 0; i < trades_in_pool; i++) {
      if (ticket == pool[i].pos_ticket) continue;
      
      int num_last_positions  =  ArraySize(last_positions);
      ArrayResize(last_positions, num_last_positions + 1);
      last_positions[num_last_positions]  =  pool[i];
   }
   
   ArrayFree(pool); 
   ArrayCopy(pool, last_positions);
   return ArraySize(last_positions);
}

void              CAutoCorrTrade::ClearPositions(void) {
   
   ArrayFree(TRADES_ACTIVE.active_positions);
   ArrayResize(TRADES_ACTIVE.active_positions, 0);
   
   ArrayFree(TRADES_ACTIVE.primary_layers);
   ArrayResize(TRADES_ACTIVE.primary_layers, 0);
   
   ArrayFree(TRADES_ACTIVE.secondary_layers);
   ArrayResize(TRADES_ACTIVE.secondary_layers, 0);
}

void              CAutoCorrTrade::CheckOrderDeadline(void) {
   
   if (InpLayerManagement == MODE_RUNNER) return;
   
   int active     = NumActivePositions();
   
   if (active == 0) return; 
   
   for (int i = 0; i < active; i++) {
      ActivePosition pos   = TRADES_ACTIVE.active_positions[i];
      if (pos.pos_deadline > TimeCurrent()) continue; 
      if (!TradeIsOpen(pos.pos_ticket)) continue;
      int c = OP_CloseTrade(pos.pos_ticket);   
      if (c) logger(StringFormat("Trade Closed: %i", PosTicket()), __FUNCTION__, true);
   }

}

void              CAutoCorrTrade::AppendActivePosition(ActivePosition &position, ActivePosition &array[]) {
   
   if (TradeInPool(position.pos_ticket, array)) return;
   int size    = ArraySize(array);
   ArrayResize(array, size + 1);
   array[size]   = position;
   
}

bool              CAutoCorrTrade::TradeIsOpen(int ticket) {
   
   int s    = OP_OrderSelectByTicket(ticket);
   if (PosCloseTime() > 0) return false; 
   return true;
   
}


int               CAutoCorrTrade::TrailStop(ActivePosition &pool[]) {

   int active  = ArraySize(pool);
   int num_modified = 0;
   
   for (int i = 0; i < active; i++) {
      int ticket = pool[i].pos_ticket;
      int s = OP_OrderSelectByTicket(ticket);
      //if (PosProfit() < 0) {
      //   int c = OP_CloseTrade(ticket);
      //   logger(StringFormat("Closed Primary Position in Drawdown: %i", ticket), __FUNCTION__);
      //}
      double trade_open_price = PosOpenPrice();
      double last_open_price  = UTIL_LAST_CANDLE_OPEN();
      
      ENUM_ORDER_TYPE   position_order_type = PosOrderType();
      int c = 0; 
      double updated_sl = PosSL();
      double current_sl = updated_sl;
      
      double   trail_factor      = InpTrailInterval * TRADE_POINTS(); 
      
      switch(position_order_type) {
      
         case ORDER_TYPE_BUY:
            updated_sl  = last_open_price - trail_factor;
            if (updated_sl <= current_sl) continue;
            break;
         case ORDER_TYPE_SELL:
            updated_sl  = last_open_price + trail_factor;
            if (updated_sl >= current_sl) continue; 
            break; 
         default:
            continue;       
      }
      c = OP_ModifySL(updated_sl);
      if (c) {
         logger(StringFormat("Trail Stop Updated. Ticket: %i", ticket), __FUNCTION__, true);
         num_modified++;
      }
      else logger(StringFormat("ERROR UPDATING SL: %i, Current: %s, Target: %s", GetLastError(), UTIL_NORM_PRICE(current_sl), UTIL_NORM_PRICE(updated_sl)), __FUNCTION__);
   }
   
   return num_modified;
}

int               CAutoCorrTrade::CloseOrder(void) {
   
   //if (InpLayerManagement == MODE_RUNNER) return 0;
   if (PosTotal() == 0) return 0;
   int num_active_positions = NumActivePositions(); 
   int tickets[];
   
   for (int i = 0; i < num_active_positions; i++) {
      int pos_ticket = TRADES_ACTIVE.active_positions[i].pos_ticket;
      if (!TradeIsOpen(pos_ticket)) continue;
      int size = ArraySize(tickets);
      ArrayResize(tickets, size+1);
      tickets[size]  = pos_ticket;
      logger(StringFormat("Added %i to close.", pos_ticket), __FUNCTION__, false, InpDebugLogging);
   }
   //logger(StringFormat("Added %i ticket/s to close", ArraySize(tickets)), __FUNCTION__, false, InpDebugLogging);
   int target_to_close  = ArraySize(tickets);
   int c = OP_OrdersCloseBatch(tickets);
   if (c == 0) {
      ClearPositions();
      logger(StringFormat("Total Batch Closed: %i.", target_to_close), __FUNCTION__, false, InpDebugLogging);
   }
   return 1;

}
double            CAutoCorrTrade::CalcLot(void) {
   
   double      risk_amount_scale_factor   = (ValueAtRisk()) / RISK_PROFILE.RP_amount; 
   double      scaled_lot                 = (RISK_PROFILE.RP_lot * InpAllocation * risk_amount_scale_factor * (1 / TICK_VALUE())); // DO NOT CHANGE
   
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
   
   current.hour      = ENTRY_HOUR();
   current.min       = ENTRY_MINUTE();
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

TradeParams       CAutoCorrTrade::TradeParamsLong(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer) {
   
   TradeParams PARAMS; 
   PARAMS.entry_price   = method == MODE_MARKET ? UTIL_PRICE_ASK() : method == MODE_PENDING ? EntryCandleOpen() : 0;
   PARAMS.sl_price      = PARAMS.entry_price - TradeDiff();
   PARAMS.tp_price      = 0;
   PARAMS.volume        = CalcLot() * layer.allocation;
   PARAMS.order_type    = method == MODE_MARKET ? ORDER_TYPE_BUY : method == MODE_PENDING ? ORDER_TYPE_BUY_LIMIT : -1; 
   PARAMS.layer         = layer;
   
   return PARAMS;


}
TradeParams       CAutoCorrTrade::TradeParamsShort(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer) {
   
   TradeParams PARAMS;
   PARAMS.entry_price   = method == MODE_MARKET ? UTIL_PRICE_BID() : method == MODE_PENDING ? EntryCandleOpen() : 0; 
   PARAMS.sl_price      = PARAMS.entry_price + TradeDiff();
   PARAMS.tp_price      = 0;
   PARAMS.volume        = CalcLot() * layer.allocation;
   PARAMS.order_type    = method == MODE_MARKET ? ORDER_TYPE_SELL : method == MODE_PENDING ? ORDER_TYPE_SELL_LIMIT : -1;
   PARAMS.layer         = layer;
   //Print("Bid: %f, Open: %f", UTIL_PRICE_BID(), UTIL_LAST_CANDLE_OPEN());
   //PrintFormat("RP LOT: %f, Tick Val: %f, Trade Points: %f", RISK_PROFILE.RP_lot, TICK_VALUE(), TRADE_POINTS());
   return PARAMS;
   
}

ENUM_DIRECTION    CAutoCorrTrade::TradeDirection(void) {
   double previous_day_diff      = PreviousDayTradeDiff(); 
   
   if (previous_day_diff == 0) return INVALID; 
   
   switch(RISK_PROFILE.RP_trade_logic) {
      case MODE_FOLLOW: 
         if (PreviousDayTradeDiff() > 0) return LONG; 
         return SHORT;
      case MODE_COUNTER:
         if (PreviousDayTradeDiff() > 0) return SHORT;
         return LONG; 
      default:
         break;
   }
   return INVALID; 
}


int               CAutoCorrTrade::SendOrder(TradeParams &PARAMS) {
   
   switch(RISK_PROFILE.RP_order_send_method) {
      case MODE_MARKET:       return SendMarketOrder(PARAMS);
      case MODE_PENDING:      return SendPendingOrder(PARAMS);
      default:                break;
   }
   return 0;
}

int               CAutoCorrTrade::Stage(void) {

   /*
      Layer logic here
   */
   TradeLayer LAYER;
   switch(RISK_PROFILE.RP_positions) {
      
      case MODE_SINGLE: 
      
         
         LAYER.layer       = LAYER_PRIMARY; 
         LAYER.allocation  = 1.0; 
         return SendOrder(SetTradeParameters(RISK_PROFILE.RP_order_send_method, LAYER)); 
         break;
         
      case MODE_LAYER: 
         return ExecuteLayer();
      default: break; 
   
   }
   
   return 0;
}

int               CAutoCorrTrade::ExecuteLayer(void) { 
   int orders_executed = 0;
   // EXECUTE PRIMARY 
   TradeLayer  PRIMARY;
   PRIMARY.layer        = LAYER_PRIMARY;
   PRIMARY.allocation   = InpPrimaryAllocation;
   
   TradeParams PRIMARY_PARAMS    = SetTradeParameters(RISK_PROFILE.RP_order_send_method, PRIMARY);
   
   int primary_ticket   = SendOrder(PRIMARY_PARAMS);
   
   if (primary_ticket < 0) return -1; // SEND PRIMARY
   // APPEND TO PRIMARY LIST 
   orders_executed++;
   
   int remaining_layers    = InpNumLayers - 1;
   double splits           = (1 - PRIMARY.allocation) / remaining_layers; // allocation for each remaining layer
   // EXECUTE SECONDARY
   for (int i = 0; i < InpNumLayers - 1; i ++) {
      TradeLayer  SECONDARY;
      SECONDARY.layer      = LAYER_SECONDARY; 
      SECONDARY.allocation = splits; 
      
      if (SendOrder(SetTradeParameters(RISK_PROFILE.RP_order_send_method, SECONDARY)) < 0) return -1;
      orders_executed++;      
   }
   PrintFormat("PRIMARY SIZE: %i, LAYER SIZE: %i", ArraySize(TRADES_ACTIVE.primary_layers), ArraySize(TRADES_ACTIVE.secondary_layers));
   return orders_executed;
}

TradeParams       CAutoCorrTrade::SetTradeParameters(ENUM_ORDER_SEND_METHOD method, TradeLayer &layer) {
   
   ENUM_DIRECTION    trade_direction   = TradeDirection(); 
   TradeParams PARAMS; 
   switch(trade_direction) {
      case LONG: 
         return TradeParamsLong(method, layer);
         break;
      case SHORT:
         return TradeParamsShort(method, layer);
         break;
      case INVALID: 
         logger("Invalid Direction", __FUNCTION__, false, InpDebugLogging);
         break; 
      default:
         break;
   }
   return PARAMS;
}

int               CAutoCorrTrade::SendMarketOrder(TradeParams &PARAMS) {
   
   string   layer_identifier  = PARAMS.layer.layer == LAYER_PRIMARY ? "PRIMARY" : "SECONDARY";
   string   comment           = StringFormat("%s_%s", EA_ID, layer_identifier);
   
   int ticket     = OP_OrderOpen(Symbol(), (ENUM_ORDER_TYPE)PARAMS.order_type, PARAMS.volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price, comment);
   
   if (ticket == -1) {
      logger(StringFormat("ORDER SEND FAILED. ERROR: %i", GetLastError()), __FUNCTION__, true);
      return -1; 
   }
   
   SetTradeWindow(TimeCurrent());
   
   ActivePosition    pos;
   pos.pos_open_datetime   =  TRADES_ACTIVE.trade_open_datetime;
   pos.pos_deadline        =  TRADES_ACTIVE.trade_close_datetime;
   pos.pos_ticket          =  ticket;
   pos.layer               =  PARAMS.layer;
   
   AppendActivePosition(pos, TRADES_ACTIVE.active_positions);
   
   switch(PARAMS.layer.layer) {
      case LAYER_PRIMARY:     AppendActivePosition(pos, TRADES_ACTIVE.primary_layers); break;
      case LAYER_SECONDARY:   AppendActivePosition(pos, TRADES_ACTIVE.secondary_layers); break;
      default: break;
   }
   
   logger(StringFormat("Updated active positions: %i, Ticket: %i", NumActivePositions(), pos.pos_ticket), __FUNCTION__);
   AddOrderToday();
   
   return ticket; 
}

ENUM_LAYER        CAutoCorrTrade::LayerType(string trade_comment) {
   
   if (StringFind(trade_comment, "PRIMARY") >= 0) return LAYER_PRIMARY; 
   if (StringFind(trade_comment, "SECONDARY") >= 0) return LAYER_SECONDARY;
   return -1;
}



int               CAutoCorrTrade::SendPendingOrder(TradeParams &PARAMS) {

   if (InvalidPriceForPendingOrder(PARAMS))     return SendMarketOrder(SetTradeParameters(MODE_MARKET, PARAMS.layer));   
   if (IsOptimalSpread())                       return SendMarketOrder(SetTradeParameters(MODE_MARKET, PARAMS.layer));
   
   string   layer_identifier  = PARAMS.layer.layer == LAYER_PRIMARY ? "PRIMARY" : "SECONDARY";
   string   comment           = StringFormat("%s_%s", EA_ID, layer_identifier); 
   
   int      ticket            = OP_OrderOpen(Symbol(), (ENUM_ORDER_TYPE)PARAMS.order_type, PARAMS.volume, PARAMS.entry_price, PARAMS.sl_price, PARAMS.tp_price, comment);
   
   if (ticket == -1) {
      logger(StringFormat("ORDER SEND FAILED. ERROR: %i", 
         GetLastError()), __FUNCTION__, true);
      return -1; 
   }
   
   SetTradeWindow(TimeCurrent());
   
   ActivePosition    pos; 
   pos.pos_open_datetime      = TRADES_ACTIVE.trade_open_datetime;
   pos.pos_deadline           = TRADES_ACTIVE.trade_close_datetime;
   pos.pos_ticket             = ticket; 
   pos.layer                  = PARAMS.layer;
   
   AppendActivePosition(pos, TRADES_ACTIVE.active_positions);

   switch(PARAMS.layer.layer) {
      case LAYER_PRIMARY:     AppendActivePosition(pos, TRADES_ACTIVE.primary_layers); break;
      case LAYER_SECONDARY:   AppendActivePosition(pos, TRADES_ACTIVE.secondary_layers); break;
      default: break;
   }
   
   logger(StringFormat("Updated active positions: %i, Ticket: %i", 
      NumActivePositions(), 
      pos.pos_ticket), __FUNCTION__);
   AddOrderToday();
   return ticket;
}

bool              CAutoCorrTrade::InvalidPriceForPendingOrder(TradeParams &PARAMS) {

   ENUM_DIRECTION trade_direction   = TradeDirection();
   switch (trade_direction) {
      case LONG:
         if (UTIL_PRICE_ASK() < PARAMS.entry_price) {
            logger(StringFormat("Invalid Price for pending order. Sending Market Order. Bid: %f, Ask: %f", 
               UTIL_PRICE_BID(), 
               UTIL_PRICE_ASK()), __FUNCTION__);
            return true;
         }
         break; 
      case SHORT: 
         if (UTIL_PRICE_BID() > PARAMS.entry_price) {
            logger(StringFormat("Invalid Price for pending order. Sending Market Order. Bid: %f, Ask: %f", 
                  UTIL_PRICE_BID(), 
                  UTIL_PRICE_ASK()), __FUNCTION__);
            return true;
         }
         break;
      case INVALID:
         break;  
      default: 
         break;
   }
   return false;

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

/*
double            CAutoCorrTrade::VolumeSplitScaleFactor(ENUM_ORDER_SEND_METHOD method) {

   if (RISK_PROFILE.RP_order_send_method != MODE_SPLIT) return 1; 
   
   switch(method) {
      case MODE_MARKET:    return RISK_PROFILE.RP_market_split; 
      case MODE_PENDING:   return 1 - RISK_PROFILE.RP_market_split;
      default: break; 
   }
   return 0;

}
*/

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
   
   if (IsTradeWindow() && NumActivePositions() == 0 && TRADES_ACTIVE.orders_today == 0) return true;
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

int            CAutoCorrTrade::ShiftToEntry(void)              { return iBarShift(Symbol(), PERIOD_CURRENT, TRADE_QUEUE.curr_trade_open); }

double         CAutoCorrTrade::EntryCandleOpen(void)           { return iOpen(Symbol(), PERIOD_CURRENT, ShiftToEntry()); }

int            CAutoCorrTrade::NumActivePositions(void)        { return ArraySize(TRADES_ACTIVE.active_positions); }
int            CAutoCorrTrade::NumPrimaryLayers(void)          { return ArraySize(TRADES_ACTIVE.primary_layers); }
int            CAutoCorrTrade::NumSecondaryLayers(void)        { return ArraySize(TRADES_ACTIVE.secondary_layers); }

double         CAutoCorrTrade::PreviousDayTradeDiff(void)      { return UTIL_PREVIOUS_DAY_CLOSE() - UTIL_PREVIOUS_DAY_OPEN();}
void           CAutoCorrTrade::errors(string error_message)    { Print("ERROR: ", error_message); }


void           CAutoCorrTrade::AddOrderToday(void)             { TRADES_ACTIVE.orders_today++; }
void           CAutoCorrTrade::ClearOrdersToday(void)          { TRADES_ACTIVE.orders_today = 0;}

double         CAutoCorrTrade::TradeDiff(void)                 { return ((RISK_PROFILE.RP_amount) / (RISK_PROFILE.RP_lot * (1 / TRADE_POINTS()))); }
double         CAutoCorrTrade::TradeDiffPoints(void)           { return (((RISK_PROFILE.RP_amount) / (RISK_PROFILE.RP_lot))); }
//double         CAutoCorrTrade::ValueAtRisk(void)               { return CalcLot() * TradeDiffPoints() * TICK_VALUE(); }

double         CAutoCorrTrade::ValueAtRisk(void) {

   double value   = ACCOUNT_RISK(); // * EQUITY SCALING HERE 
   return value;

}