//+------------------------------------------------------------------+
//|                                               GhorbaniScript.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include<Trade\SymbolInfo.mqh>
#include <trade/Trade.mqh>


input datetime startDateTime = "16:30:00";
input datetime endDateTime = "17:00:00";
input ENUM_TIMEFRAMES timeFrame = PERIOD_M1;
input int    startPip  =15;
input double BalanceProfitPercent = 3;
input double BalanceLimitPercent = 5;
input int    TakeProfit=3000;
input int    StopLoss  =3000;
//input double lot       =0.1;
input bool trailingStopLoss = true;
input double trailingStopLossPercentage = 50;

double MagicNumber;
bool cantrade=true;
bool tradeStarted = false;
double Ask;
double Bid;
double startBalance;
double balance;
double profitStop;
double limit;

ENUM_ORDER_TYPE orderType;
double sl;
double tp;

CAccountInfo account;
CSymbolInfo symbol_info;
CTrade  trade;
CPositionInfo position;
   
int OnInit()
{
   // check access
   long login=account.Login();
   if(!account.TradeAllowed())
      Alert("???? Allow Trading ?? ?????? ????");
   
   // print info
   symbol_info.Name(_Symbol);
   symbol_info.RefreshRates();
   Print(symbol_info.Name()," (",symbol_info.Description(),")","  Bid=",symbol_info.Bid(),"   Ask=",symbol_info.Ask());
   
   // set magic number
   MagicNumber=13400;
   trade.SetExpertMagicNumber(MagicNumber);
   
   trade.LogLevel(1); 
   
      
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print(__FUNCTION__," Deinitialization reason code = ",reason);
}

void OnTick()
{
   balance = MathRound(NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE),_Digits));
      
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   Ask=last_tick.ask;
   Bid=last_tick.bid;
   
   if(IsNewDay()){
      Print("new day, ", TimeCurrent());
      tradeStarted = false;
      
      startBalance = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE),_Digits);
      Print("balance: ", startBalance);
      
      profitStop = NormalizeDouble((startBalance * BalanceProfitPercent / 100),_Digits);
      Print("BalanceProfitPercent: ", BalanceProfitPercent);
      Print("profitStop: ", profitStop);
      
      limit = -NormalizeDouble((startBalance * BalanceLimitPercent / 100),_Digits);
      Print("BalanceLimitPercent: ", BalanceLimitPercent);
      Print("limit: ", limit);
   }
   
   RiskFree();
   if(OrdersTotal() > 0 && (OrdersTotal() > 0 || PositionsTotal() > 0)) return;
   if(TimeCurrent() < GetStartDateTime()) return;
   if(TimeCurrent() > GetEndDateTime()) return;
      
   if(!tradeStarted) {
      Print("wait to rich tp ", startPip);
      double openPrice = iOpen(_Symbol, timeFrame, 0);
   
    if(GetStartPrice() + startPip <= openPrice) {
       Print("trade started for buy");
       int id = OpenBuy();
       tradeStarted = true;
    }
    else if(GetStartPrice() - startPip >= openPrice) {
       Print("trade started for sell");
       int id = OpenSell();
       tradeStarted = true;
    }
    return;
   }
  
  if(OrdersTotal() > 0) return;
  if(sl == 0) return;
 
  //Print("IsRiched Profit: ", DayProfit() >= profitStop, " profitStop: ", profitStop, " balance: ", balance);
  //Print("IsRiched limit: ", DayProfit() <= limit, " limit: ", limit, " balance: ", balance);
  Print("DayProfit: ", DayProfit());
  if(DayProfit() >= profitStop) return;
  if(DayProfit() <= limit) return;
   
  double price;
  if(orderType == ORDER_TYPE_BUY) {
   price = Ask;
   if(price >= tp){
      Print("Price, Ask, Buy (riced tp for buy): ", price);
      int id = OpenBuy();
   }
   else if(price <= sl){
      Print("Price, Ask, Buy (riced sl for sell): ", price);
      int id = OpenSell();
   }
  }
  else if(orderType == ORDER_TYPE_SELL){
   price = Bid;
   if(price <= tp){
      Print("Price, Bid, Buy (riced tp): ", price);
      int id = OpenSell();
   }
   else if(price >= sl){
      Print("Price, Bid, Buy (riced sl): ", price);
      int id = OpenBuy();
   }
  }
  
}
void RiskFree()
{
uint PositionsCount = PositionsTotal();
if(trailingStopLoss && PositionsCount > 0)
  {
   for(int i = PositionsCount-1; i >= 0; i--)
     {
      if(position.SelectByIndex(i) && position.Symbol() == Symbol())
        {
         Print("----------------------------------------------------------------> check for trailing");
         ENUM_POSITION_TYPE type = position.PositionType();
         double CurrentTP = position.TakeProfit();
         double CurrentPrice = position.PriceCurrent();
         
         double positionOpenPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), Digits());
         Print("positionOpenPrice: ", positionOpenPrice);
         
         double tp = 0;
         if(type == POSITION_TYPE_SELL)
         {
            tp = NormalizeDouble(positionOpenPrice - CurrentTP, Digits());
         }
         else if(type == POSITION_TYPE_BUY)
         {
            tp = NormalizeDouble(CurrentTP - positionOpenPrice, Digits());
         }
         
         double profitRich = NormalizeDouble((tp * trailingStopLossPercentage / 100),_Digits);
         Print("tp: ", tp);
         Print("CurrentPrice: ", CurrentPrice);
         Print("CurrentTP: ", CurrentTP);
         Print("profitRich: ", profitRich);
         
         double profitPrice = 0;
         if(type == POSITION_TYPE_SELL)
         {
            profitPrice = NormalizeDouble(positionOpenPrice - profitRich, Digits());
         }
         else if(type == POSITION_TYPE_BUY)
         {
            profitPrice = NormalizeDouble(positionOpenPrice + profitRich, Digits());
         }
         Print("profitPrice: ", profitPrice);
         
         if(type == POSITION_TYPE_BUY && CurrentPrice >= profitPrice)
           {
               Print("+++++++++++++++++++ Position modified for Buy +++++++++++++++++++");
               trade.PositionModify(position.Ticket(), NormalizeDouble(positionOpenPrice, Digits()), CurrentTP);
           }
         else if(type == POSITION_TYPE_SELL && CurrentPrice <= profitPrice)
           {
               Print("------------------- Position modified for Sell -------------------");
               trade.PositionModify(position.Ticket(), NormalizeDouble(positionOpenPrice, Digits()), CurrentTP);
           }
        }
     }
  }
}

double DayProfit(){
    double   profits  = 0.0;
    double   dayprof  = 0.0;
    double   dayloss  = 0.0;
    datetime end      = TimeCurrent(); 
    
    MqlDateTime fromDateTime;
    TimeToStruct(end,fromDateTime);
    datetime start = StringToTime(fromDateTime.year + "/" + fromDateTime.mon + "/" + (fromDateTime.day) + " " + "2:00:00");
    
    HistorySelect(start,end);

    int TotalDeals = HistoryDealsTotal();
    for(int i = 0; i < TotalDeals; i++) {
        ulong    ticket   = HistoryDealGetTicket(i);
        string   symbol   = HistoryDealGetString(ticket , DEAL_SYMBOL);
        ulong    magic    = HistoryDealGetInteger(ticket, DEAL_MAGIC);
        long     dealType = HistoryDealGetInteger(ticket, DEAL_ENTRY);

        bool C1 = symbol == _Symbol && magic == MagicNumber && dealType == DEAL_ENTRY_OUT;
        if(C1){
            double LatestProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            profits += HistoryDealGetDouble(ticket, DEAL_PROFIT);

            if (HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0){
                dayprof += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            }

            if (HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0){
                dayloss += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            }            
        }  

    }
   //Print("Function result - profits : ", profits);
   //Print("Function result - dayprof : ", dayprof);
   //Print("Function result - dayloss : ", dayloss);    
   return NormalizeDouble(profits,_Digits);
}
datetime GetStartDateTime() {
   MqlDateTime current;
   TimeCurrent(current);
   
   MqlDateTime start;
   TimeToStruct(startDateTime, start);
   return StringToTime(current.year + "." + current.mon + "." + current.day + " " + start.hour + ":" + start.min);
}
datetime GetEndDateTime() {
   MqlDateTime current;
   TimeCurrent(current);
   
   MqlDateTime end;
   TimeToStruct(endDateTime, end);
   return StringToTime(current.year + "." + current.mon + "." + current.day + " " + end.hour + ":" + end.min);
}
double GetStartPrice() {
   return iOpen(_Symbol, timeFrame, iBarShift(_Symbol, timeFrame, GetStartDateTime(), true));
}
bool IsNewDay(){
   static datetime prevDay = -1;
   if( iTime(_Symbol, PERIOD_D1, 0) == prevDay ) return false;
   prevDay = iTime(_Symbol, PERIOD_D1, 0);
   return true;
}
int OpenSell(int slippage=20,string comment="created by mql",int magic=13400)
  {
   Print("sell");
   MqlTradeRequest request={};
   request.action=TRADE_ACTION_DEAL;
   request.magic=magic;
   request.symbol=_Symbol;
   request.volume=CalculateLatage();
   sl = NormalizeDouble(Bid+StopLoss*_Point,_Digits);
   request.sl=sl;
   tp = NormalizeDouble(Bid-TakeProfit*_Point,_Digits);
   request.tp=tp;
   orderType = ORDER_TYPE_SELL;
   request.type=orderType;
   request.price=NormalizeDouble(Bid,_Digits);
   MqlTradeResult result={};
   
   if(OrdersTotal() > 0) return 0;
   OrderSend(request,result);
   
   Print(__FUNCTION__,":",result.comment);
   if(result.retcode==10016) Print(result.bid,result.bid,result.price);
   return result.retcode;  
}
int OpenBuy(int slippage=20,string comment="created by mql",int magic=13400)
  {
   Print("buy");
   MqlTradeRequest request={};
   request.action=TRADE_ACTION_DEAL;
   request.magic=magic;
   request.symbol=_Symbol;
   request.volume=CalculateLatage();
   sl = NormalizeDouble(Ask-(StopLoss*_Point),_Digits);
   request.sl=sl;
   tp = NormalizeDouble(Ask+(TakeProfit*_Point),_Digits);
   request.tp=tp;    
   orderType = ORDER_TYPE_BUY;
   request.type=orderType;
   request.price=NormalizeDouble(Ask,_Digits);
   MqlTradeResult result={};
   
   if(OrdersTotal() > 0) return 0;
   OrderSend(request,result);
   
   Print(__FUNCTION__,":",result.comment);
   if(result.retcode==10016) Print(result.bid,result.ask,result.price);
   return result.retcode;
}
double CalculateLatage() {
   double lot = NormalizeDouble(startBalance / 10000,_Digits);
   Print("lot: ", lot);
   if(lot >= 48)
      lot = 40;
   return lot;
}