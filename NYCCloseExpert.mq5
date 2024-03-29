#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include<Trade\SymbolInfo.mqh>
#include <trade/Trade.mqh>
CAccountInfo account;
CSymbolInfo symbol_info;
CTrade  trade;
CPositionInfo position;
COrderInfo     m_order;


input string closeTime = "23:30:00";
input datetime startDateTime = "10:30:00";
input datetime endDateTime = "20:00:00";
input int TakeProfit = 1500;
input int StopLoss = 7000;
input bool trailingStopLoss = true;
input double trailingStopLossPercentage = 50;
input bool IsCloseAllPositionEndOfDay = true;
input bool IsOpenOneTradeAtTime = true;

double MagicNumber = 13400;
double close;
double startBalance;
double Ask;
double Bid;

int OnInit() {
   // check access
   long login=account.Login();
   if(!account.TradeAllowed())
      Alert("turn on Allow Trading");
   
   // print info
   symbol_info.Name(_Symbol);
   symbol_info.RefreshRates();
   Print(symbol_info.Name()," (",symbol_info.Description(),")","  Bid=",symbol_info.Bid(),"   Ask=",symbol_info.Ask());
   
   trade.LogLevel(1); 
      
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   
}

void OnTick() {
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   Ask=last_tick.ask;
   Bid=last_tick.bid;
   
   if(IsCloseAllPositionEndOfDay)
      CloseAllPositions();
   
   if(IsNewDay()){
      Print("New day " + TimeCurrent());
      
      startBalance = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE),_Digits);
      Print("balance: ", startBalance);
      
      close = YesterDayCloseBar();
      Print("Last day Close: ", close);
      Comment("Yesterday Close: ", close);
   }
   
   RiskFree();
   
   if(IsOpenOneTradeAtTime && (OrdersTotal() > 0 || PositionsTotal() > 0)) return;
   if(TimeCurrent() < GetStartDateTime()) return;
   if(TimeCurrent() > GetEndDateTime()) return;
   
   bool isBullish = iOpen(Symbol(),PERIOD_M1,1) < Bid ? true : false;
   //Print("price: ", Bid, " IsBullish: ", isBullish);
   
   if(Bid == close) {
    if(!isBullish) {
       Print("(Buy) sell price: ", Bid);
       OpenBuy();
    }
    else if(isBullish) {
       Print("(Sell) buy price: ", Bid);
       OpenSell();
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
void CloseAllPositions() {
   MqlDateTime current;
   TimeCurrent(current);
   
   MqlDateTime closeAllDateTime;
   TimeToStruct("23:30:00", closeAllDateTime);
   
   MqlDateTime closeUntilDateTime;
   TimeToStruct("23:59:00", closeUntilDateTime);
   
   if ((current.hour >= closeAllDateTime.hour && current.min >= closeAllDateTime.min) 
   && (current.hour <= closeUntilDateTime.hour && current.min <= closeUntilDateTime.min)) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(position.SelectByIndex(i))  // select a position
        {
         trade.PositionClose(position.Ticket()); // then close it --period
        }
       }
        //-- Orders
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(m_order.SelectByIndex(i))  // select an order
        {
         trade.OrderDelete(m_order.Ticket()); // then delete it --period
        }
       }
//--End 
//-- Positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(position.SelectByIndex(i))  // select a position
        {
         trade.PositionClose(position.Ticket()); // then close it --period
        }
       }
    }
//--End 
}

int OpenSell(int slippage=20,string comment="created by mql")
  {
   MqlTradeRequest request={};
   request.action=TRADE_ACTION_DEAL;
   request.magic=MagicNumber;
   request.symbol=_Symbol;
   request.volume=CalculateLatage();
   double sl = NormalizeDouble(Bid+StopLoss*_Point,_Digits);
   request.sl=sl;
   double tp = NormalizeDouble(Bid-TakeProfit*_Point,_Digits);
   request.tp=tp;
   request.type=ORDER_TYPE_SELL;
   request.price=NormalizeDouble(Bid,_Digits);
   request.type_filling = ORDER_FILLING_IOC;
   MqlTradeResult result={};
   OrderSend(request,result);
   
   Print(__FUNCTION__,":",result.comment);
   if(result.retcode==10016) Print(result.bid,result.bid,result.price);
   return result.retcode;  
}
int OpenBuy(int slippage=20,string comment="created by mql")
  {
   MqlTradeRequest request={};
   request.action=TRADE_ACTION_DEAL;
   request.magic=MagicNumber;
   request.symbol=_Symbol;
   request.volume=CalculateLatage();
   double sl = NormalizeDouble(Ask-(StopLoss*_Point),_Digits);
   request.sl=sl;
   double tp = NormalizeDouble(Ask+(TakeProfit*_Point),_Digits);
   request.tp=tp;    
   request.type=ORDER_TYPE_BUY;
   request.price=NormalizeDouble(Ask,_Digits);
   request.type_filling = ORDER_FILLING_IOC;
   MqlTradeResult result={};
   OrderSend(request,result);
   
   Print(__FUNCTION__,":",result.comment);
   if(result.retcode==10016) Print(result.bid,result.ask,result.price);
   return result.retcode;
}
//bool IsBullish() {
//   bool bullish = iOpen(Symbol(),PERIOD_M1,1) < iClose(Symbol(),PERIOD_M1,1) ? true : false;
//   return bullish;
//}
bool IsNewDay(){
   static datetime prevDay = -1;
   if( iTime(_Symbol, PERIOD_D1, 0) == prevDay ) return false;
   prevDay = iTime(_Symbol, PERIOD_D1, 0);
   return true;
}
double YesterDayCloseBar() {
   datetime yesterday = TimeCurrent() - 60 * 60 * 24;
   MqlDateTime yesterdayDateTime;
   TimeToStruct(yesterday,yesterdayDateTime);
   datetime lastDateTime = StringToTime(yesterdayDateTime.year + "/" + yesterdayDateTime.mon + "/" + (yesterdayDateTime.day) + " " + closeTime);

   int shift = iBarShift(_Symbol, PERIOD_M1, lastDateTime);
   return iClose(_Symbol, PERIOD_M1, shift);
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
double CalculateLatage() {
   double lot = NormalizeDouble(startBalance / 10000,_Digits);
   Print("lot: ", lot);
   if(lot >= 48)
      lot = 40;
   return lot;
}