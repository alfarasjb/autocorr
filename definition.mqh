#include <MAIN/CalendarDownloader.mqh>
#include <MAIN/utilities.mqh>
/*
TODOS
   Order Management:
      1. Market
      2. Pending
      3. Split 
      
      
*/

// ========== ENUM ========== // 

enum ENUM_DIRECTION {
   LONG, SHORT, INVALID
};

enum ENUM_TRADE_MANAGEMENT {
   MODE_BREAKEVEN, MODE_TRAILING, MODE_NONE
};

enum ENUM_POSITION_SIZING {
   MODE_DYNAMIC, MODE_STATIC
};

enum ENUM_ORDER_SEND_METHOD {
   MODE_MARKET, MODE_PENDING, MODE_SPLIT
};

enum ENUM_TRADE_LOGIC {
   MODE_FOLLOW, MODE_COUNTER
};

// =========== STRUCT ========== // 

struct RiskProfile {
   double                  RP_amount, RP_lot, RP_market_split;
   int                     RP_half_life; 
   ENUM_TIMEFRAMES         RP_timeframe; 
   ENUM_ORDER_SEND_METHOD  RP_order_send_method;
   ENUM_TRADE_LOGIC        RP_trade_logic;

} RISK_PROFILE;

struct ActivePosition {

   datetime    pos_open_datetime, pos_deadline; 
   int         pos_ticket;

};

struct TradeQueue {
   datetime next_trade_open, next_trade_close, curr_trade_open, curr_trade_close;
} TRADE_QUEUE;

struct TradeParams {
   double entry_price, sl_price, tp_price, volume;
};

struct TradesActive {
   int      orders_today;
   datetime trade_open_datetime, trade_close_datetime;
   
   ActivePosition active_positions[];
} TRADES_ACTIVE;


input string                  InpRiskProfile       = " ========== RISK PROFILE =========="; // 
input float                   InpRPDeposit         = 100000; // RISK PROFILE: DEPOSIT
input float                   InpRPRiskPercent     = 1; // RISK PROFILE: RISK PERCENT
input float                   InpRPLot             = 10; // RISK PROFILE: LOT
input int                     InpRPHalfLife        = 4; // RISK PROFILE: HALF LIFE
input ENUM_TIMEFRAMES         InpRPTimeframe       = PERIOD_M30; // RISK PROFILE: TIMEFRAME
input ENUM_ORDER_SEND_METHOD  InpRPOrderSendMethod = MODE_PENDING; // RISK PROFILE: ORDER SEND METHOD
input float                   InpRPMarketSplit     = 0.5; // RISK PROFILE: SCALE FACTOR 
input ENUM_TRADE_LOGIC        InpRPTradeLogic      = MODE_FOLLOW; // RISK PROFILE: TRADE LOGIC


input string                  InpEntry             = " ========== ENTRY WINDOW =========="; //
input bool                    InpLoadFromFile      = false; // LOAD FROM FILE
input int                     InpEntryHour         = 0; // ENTRY WINDOW HOUR
input int                     InpEntryMin          = 0; // ENTRY WINDOW MINUTE

input string                  InpRiskMgt           = " ========== RISK MANAGEMENT =========="; 
input float                   InpRiskAmount        = 1000; // BASE RISK AMOUNT
input float                   InpAllocation        = 1; // ALLOCATION
input ENUM_TRADE_MANAGEMENT   InpTradeMgt          = MODE_NONE; // TRADE MANAGEMENT
input float                   InpTrailInterval     = 100; // TRAILING STOP INTERVAL
input double                  InpCutoff            = 0.85; // EQUITY CUTOFF
input float                   InpMaxLot            = 1; // MAX LOT
input ENUM_POSITION_SIZING    InpSizing            = MODE_DYNAMIC; // POSITION SIZING
input float                   InpDDScale           = 0.5; // DRAWDOWN SCALING
input float                   InpAbsDDThresh       = 10; // ABSOLUTE DRAWDOWN THRESHOLD
input double                  InpEquityDDThresh    = 5; // EQUITY DRAWDOWN THRESHOLD

input string                  InpMisc              = " ========== MISC ==========";
input int                     InpMagic             = 232323; // MAGIC NUMBER
input bool                    InpShowUI            = false; // SHOW UI
input bool                    InpTradeOnNews       = false; // TRADE ON NEWS
input Source                  InpNewsSource        = R4F_WEEKLY; // NEWS SOURCE

input string                  InpLogging           = " ========== LOGGING =========";
input bool                    InpTerminalMsg       = true; // TERMINAL LOGGING 
input bool                    InpPushNotifs        = false; // PUSH NOTIFICATIONS
input bool                    InpDebugLogging      = false; // DEBUG LOGGING



// Syntax: <Abbreviation>-<Date Deployed>-<Base Version>
// DO NOT CHANGE

const string   EA_ID                = "AC-021924-1";
const string   FXFACTORY_DIRECTORY  = "autocorrelation\\ff_news";
const string   R4F_DIRECTORY        = "autocorrelation\\r4f_news"; 