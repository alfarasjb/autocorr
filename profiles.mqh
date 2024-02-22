



struct TradeProfile {
   string      trade_symbol;
   datetime    trade_open_time; 
   int         trade_half_life, trade_lot, trade_magic;
   double      trade_risk_percent;
} TRADE_PROFILE;



class CProfiles {
   
   protected:
   private:
   public:
   
      int      FILE_HANDLE;
      string   FILE_PATH;
   
      CProfiles(string path); 
      ~CProfiles();
      
      TradeProfile   BuildProfile();  
      int            ClearHandle();
};


CProfiles::CProfiles(string path) {
   FILE_PATH = path;
   

}

CProfiles::~CProfiles(void) {
   ClearHandle();
}

int               CProfiles::ClearHandle(void) { 

   FileClose(FILE_HANDLE);
   FileFlush(FILE_HANDLE);
   FILE_HANDLE = 0;
   return FILE_HANDLE;

}

TradeProfile     CProfiles::BuildProfile(void) {

   ResetLastError();
   ClearHandle(); 
   
   if (!FileIsExist(FILE_PATH)) {
      PrintFormat("%s File %s not found.", __FUNCTION__, FILE_PATH);
   } 
   else PrintFormat("%s File %s found", __FUNCTION__, FILE_PATH);
   
   FILE_HANDLE    = FileOpen(FILE_PATH, FILE_CSV | FILE_READ | FILE_ANSI, "\n");
   if (FILE_HANDLE == -1) return TRADE_PROFILE; 
   
   string      result[];
   
   while (!FileIsLineEnding(FILE_HANDLE)) {
      string file_string = FileReadString(FILE_HANDLE);
      
      int split = (int)StringSplit(file_string, ',', result);
      
      if (split < 6) continue; 
      
      if (result[0] != Symbol()) continue; 
      
      PrintFormat("%s PROFILE FOUND FOR %s", __FUNCTION__, Symbol());
      TRADE_PROFILE.trade_symbol       = result[0];
      TRADE_PROFILE.trade_open_time    = StringToTime(result[1]); 
      TRADE_PROFILE.trade_lot          = (int)result[2];
      TRADE_PROFILE.trade_risk_percent = (double)result[3] * 100; 
      TRADE_PROFILE.trade_half_life    = (int)result[4];      
      TRADE_PROFILE.trade_magic        = (int)result[5];
      
   }
   ClearHandle();
   return TRADE_PROFILE;
}
