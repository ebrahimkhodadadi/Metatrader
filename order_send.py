import time
import MetaTrader5 as mt5

def Login(server, user, password):
    # establish connection to the MetaTrader 5 terminal
    if not mt5.initialize(login=user, server=server,password=password):
        print("initialize() failed, error code =",mt5.last_error())
        quit()

def CheckSymbol(symbol):
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        print(symbol, "not found, can not call order_check()")
        mt5.shutdown()
        quit() 
    # if the symbol is unavailable in MarketWatch, add it
    if not symbol_info.visible:
        print(symbol, "is not visible, trying to switch on")
        if not mt5.symbol_select(symbol,True):
            print("symbol_select({}}) failed, exit",symbol)
            mt5.shutdown()
            quit()
        
def OpenOrder(type, lot, symbol, sl_pips, tp_pips):
    #time.sleep(1)
    
    # Get filling mode 
    #filling_mode = mt5.symbol_info(symbol).filling_mode - 1

    # Take ask price
    ask_price = mt5.symbol_info_tick(symbol).ask

    # Take bid price
    bid_price = mt5.symbol_info_tick(symbol).bid

    # Take the point of the asset
    point = mt5.symbol_info(symbol).point

    deviation = 20  # mt5.getSlippage(symbol)
    
    print('type: {0}'.format(type))
    print('bid_price: {0}'.format(bid_price))
    print('ask_price: {0}'.format(ask_price))
    print('sl_pips: {0}'.format(sl_pips))
    print('tp_pips: {0}'.format(tp_pips))
        
    price = 0
    if type == mt5.ORDER_TYPE_BUY:
        sl = ask_price - (sl_pips * point)
        tp = ask_price + (tp_pips * point)
        price = ask_price
      # Sell order Parameters
    elif type == mt5.ORDER_TYPE_SELL:
        sl = bid_price + (sl_pips * point)
        tp = bid_price - (tp_pips * point)
        price = bid_price

    print('sl: {0}'.format(sl))
    print('tp: {0}'.format(tp))
    print('price: {0}'.format(price))
    
    # Open the trade
    request = {
          "action": mt5.TRADE_ACTION_DEAL,
          "symbol": symbol,
          "volume": lot,
          "type": type,
          "price": price,
          "deviation": deviation,
          "sl": sl,
          "tp": tp,
          "magic": 234000,
          "comment": "python script order",
          "type_time": mt5.ORDER_TIME_GTC,
          "type_filling": mt5.ORDER_FILLING_IOC,
      }

    # create a open request
    # send a trading request
    result = mt5.order_send(request)
    # check the execution result
    if result is not None:
        # check the execution result
        print("1. order_send(): by {} {} lots at {} with deviation={} points".format(symbol, lot, price, deviation))
        if result.retcode != mt5.TRADE_RETCODE_DONE:
            print("2. order_send failed, retcode={}".format(result.retcode))
            
            # Print the error message
            error_message = mt5.last_error()
            print(f"   Error message: {error_message}")

            # request the result as a dictionary and display it element by element
            result_dict = result._asdict()
            for field in result_dict.keys():
                print("   {}={}".format(field, result_dict[field]))
                
                # if this is a trading request structure, display it element by element as well
                if field == "request":
                    traderequest_dict = result_dict[field]._asdict()
                    for tradereq_filed in traderequest_dict:
                        print("       traderequest: {}={}".format(tradereq_filed, traderequest_dict[tradereq_filed]))
                        
            print("shutdown() and quit")
            mt5.shutdown()
            quit()
    else:
        print("1. order_send failed. Exiting.")
        mt5.shutdown()
        quit()          
    
    return result;

def CloseOrder(position_id, symbol, type, lot=0.1):
    price = 0
    if type == mt5.ORDER_TYPE_BUY:
        price = mt5.symbol_info_tick(symbol).ask
    else:
        price = mt5.symbol_info_tick(symbol).bid
            
    # Close the position using the order ticket obtained from the open position result
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lot,
        "type": type,
        "position": position_id,  # Use the order ticket obtained from the open position result
        "price": price,
        "deviation": 20,
        "magic": 234000,
        "comment": "python script close",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    # Send a trading request to close the position
    result = mt5.order_send(request)

    # check the execution result
    print("3. close position #{}: sell {} points".format(position_id,symbol));
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        print("4. order_send failed, retcode={}".format(result.retcode))
        print("   result",result)
    else:
        print("4. position #{} closed, {}".format(position_id,result))
        # request the result as a dictionary and display it element by element
        result_dict=result._asdict()
        for field in result_dict.keys():
            print("   {}={}".format(field,result_dict[field]))
            # if this is a trading request structure, display it element by element as well
            if field=="request":
                traderequest_dict=result_dict[field]._asdict()
                for tradereq_filed in traderequest_dict:
                    print("       traderequest: {}={}".format(tradereq_filed,traderequest_dict[tradereq_filed]))

def MonitorPosition(symbol, position_id, take_profit, stop_loss, type):
    while True:
        # Retrieve the current position information
        position_info = mt5.positions_get(ticket=position_id)
        
        price = 0
        if type == mt5.ORDER_TYPE_BUY:
            price = mt5.symbol_info_tick(symbol).ask
        else:
            price = mt5.symbol_info_tick(symbol).bid
        
        if position_info:
            # Extract relevant information from the position
            price = position_info[0].price_open
            take_profit = position_info[0].tp
            stop_loss = position_info[0].sl
            
            # Check if take profit or stop loss is reached
            
            if type == mt5.ORDER_TYPE_BUY:
                if price >= take_profit:
                    print("1.Take Profit reached. Closing position.")
                    CloseOrder(position_id=position_id, symbol=symbol,type=mt5.ORDER_TYPE_BUY)
                    Start(mt5.ORDER_TYPE_BUY)
                    break
                elif price <= stop_loss:
                    print("2.Stop Loss reached. Closing position.")
                    CloseOrder(position_id=position_id, symbol=symbol,type=mt5.ORDER_TYPE_SELL)
                    Start(mt5.ORDER_TYPE_SELL)
                    break
            elif type == mt5.ORDER_TYPE_SELL:
                if price <= take_profit:
                    print("2.Stop Loss reached. Closing position.")
                    CloseOrder(position_id=position_id, symbol=symbol,type=mt5.ORDER_TYPE_SELL)
                    Start(mt5.ORDER_TYPE_SELL)
                    break
                elif price >= stop_loss:
                    print("1.Take Profit reached. Closing position.")
                    CloseOrder(position_id=position_id, symbol=symbol,type=mt5.ORDER_TYPE_BUY)
                    Start(mt5.ORDER_TYPE_BUY)
                    break
        else:
            if type == mt5.ORDER_TYPE_BUY:
                if price >= take_profit:
                    print("3.Take Profit reached. Closing position.")
                    Start(mt5.ORDER_TYPE_BUY)
                    break
                elif price <= stop_loss:
                    print("4.Stop Loss reached. Closing position.")
                    Start(mt5.ORDER_TYPE_SELL)
                    break
            elif type == mt5.ORDER_TYPE_SELL:
                if price <= take_profit:
                    print("4.Stop Loss reached. Closing position.")
                    Start(mt5.ORDER_TYPE_SELL)
                    break
                elif price >= stop_loss:
                    print("3.Take Profit reached. Closing position.")
                    Start(mt5.ORDER_TYPE_BUY)
                    break
            
        # Add a delay to avoid excessive API calls
        #time.sleep(1)
              

def Start(type):
    symbol = "DJIUSD"
    lot=0.1
    
    Login("server", 1122223333, "passs")
    
    CheckSymbol(symbol)
    
    result = OpenOrder(type,lot=lot, symbol=symbol, sl_pips=1500, tp_pips=3000)
    position_id = result.order
    
    MonitorPosition(symbol, position_id, result.request.tp, result.request.sl, type)
    
if __name__ == '__main__':    
    Start(type=mt5.ORDER_TYPE_SELL)

mt5.shutdown()

