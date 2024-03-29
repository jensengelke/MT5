#property copyright "DerJens 2023"
#property version   "1.00"

#include<Trade\Trade.mqh>

input string symbol_to_cancel = "GOLD";
input double close_x_percent = 100.0;
input int loglevel = 2;
input int    myMagic = 20231006;
input double order_open_volume = 1.00;

CTrade *trade = new CTrade();

int last_positions_total = -1;
int last_orders_total    = -1;

ulong last_positions[];
ulong last_orders[];

int day=-1;


int OnInit()  {
   int result = INIT_SUCCEEDED;
   if (close_x_percent < 0 || close_x_percent > 100)  {
      result = INIT_PARAMETERS_INCORRECT;
      PrintFormat("close_x_percent muss zwischen 0.0 und 100.0 liegen.");
   }
   
   getCurrentState();   
   
   trade.SetExpertMagicNumber(myMagic);
   return(result);
}

void OnTick(void) {
   string methodname="OnTick()";
   MqlDateTime now;
   TimeCurrent(now);
   
   if (now.day != day) {
     printlog(2,methodname,StringFormat("day=%d, today=%d", day, now.day));
     day=now.day;
     
     bool success=false;
     int mode=day%4;
     double price = SymbolInfoDouble(symbol_to_cancel, SYMBOL_BID);
     
     switch(mode){
      case 0: 
         success=trade.Sell(order_open_volume, symbol_to_cancel, price, 0.0, 0.0, "dummy");
         break;
      case 1:
         price = SymbolInfoDouble(symbol_to_cancel, SYMBOL_ASK);
         success=trade.Buy(order_open_volume, symbol_to_cancel, price, 0.0, 0.0, "dummy");
         break;
      case 2:
         price = NormalizeDouble( SymbolInfoDouble(symbol_to_cancel, SYMBOL_BID)*0.99, (int)SymbolInfoInteger(symbol_to_cancel,SYMBOL_DIGITS));
         success=trade.SellStop(order_open_volume, price, symbol_to_cancel, 0.0, 0.0, ORDER_TIME_DAY, 0, "dummy");
         break;
      case 3:
         price = NormalizeDouble( SymbolInfoDouble(symbol_to_cancel, SYMBOL_BID)*1.01, (int)SymbolInfoInteger(symbol_to_cancel,SYMBOL_DIGITS));
         success=trade.BuyStop(order_open_volume, price, symbol_to_cancel, 0.0, 0.0, ORDER_TIME_DAY, 0, "dummy");
         break;
     }
     
     if (!success) {
      printlog(0,methodname, StringFormat("ERROR: retcode%d", trade.ResultRetcode()));
     }
   }
}

void getCurrentState() {
   string methodname = "getCurrentState()";
   last_positions_total = PositionsTotal();
   last_orders_total    = OrdersTotal();
   
   printlog(1, methodname, StringFormat("pos count: %d, order count: %d", last_positions_total, last_orders_total));
   
   if (last_positions_total > 0) {
      ulong current_positions[];
      ArrayResize(current_positions,last_positions_total,0);
      for (int p=0; p<last_positions_total; p++) {
         current_positions[p] = PositionGetTicket(p);
         printlog(2, methodname, StringFormat(" > tracking pos ticket %d", current_positions[p]));
      }
      ArraySwap(last_positions, current_positions);
      ArraySort(last_positions);
   }
   
   if (last_orders_total > 0) {
      ulong current_orders[];
      ArrayResize(current_orders,last_orders_total,0);
      for (int o=0; o<last_orders_total;o++) {
         current_orders[o]=OrderGetTicket(o);
         printlog(2, methodname, StringFormat(" > tracking order ticket %d", current_orders[o]));
      }
      ArraySwap(last_orders, current_orders);
      ArraySort(last_orders);
   }
}

void printlog(int level, string methodname, string message) {
   if (level <= loglevel) {
      PrintFormat("%i %s %s", level, methodname, message);
   }
}


void OnTrade(){
   string methodname = "OnTrader()";
   int current_positions_total = PositionsTotal();
   if (current_positions_total != last_positions_total) {
      printlog(0, methodname, StringFormat("Anzahl der Positionen hat sich geändert: alt=%d, neu=%d", last_positions_total, current_positions_total));
      for (int p=0; p<current_positions_total;p++) {
         ulong pticket = PositionGetTicket(p);
         string psymbol = PositionGetString(POSITION_SYMBOL);
         if (psymbol != symbol_to_cancel) {
            printlog(2, methodname, StringFormat("Ignoriere Positionsticket %d für irrelevantes Symbol %s", pticket, psymbol));
         } else {
            if (isExistingTicket(last_positions, pticket)) {
               printlog(2, methodname, StringFormat("Das Positionsticket %d war schon bekannt - keine Änderung", pticket));
            } else {
               printlog(1, methodname, StringFormat("Positionsticket %d ist neu und für das interessante Symbol. Action required.",pticket));
               reducePositionSize(pticket);
            }
         } 
      }
   }
   
   int current_orders_total = OrdersTotal();
   if (current_orders_total != last_orders_total) {
      printlog(0, methodname, StringFormat("Anzahl der Orders hat sich geändert: alt=%d, neu=%d", last_orders_total, current_orders_total));
      for (int o=0; o<current_orders_total;o++) {
         ulong oticket = OrderGetTicket(o);
         string osymbol = OrderGetString(ORDER_SYMBOL);
         if (osymbol != symbol_to_cancel) {
            printlog(2, methodname, StringFormat("Ignoriere Orderticket %d für irrelevantes Symbol %s", oticket, osymbol));
         } else {
            if (isExistingTicket(last_orders, oticket)) {
               printlog(2, methodname, StringFormat("Das Orderticket %d war schon bekannt - keine Änderung", oticket));
            } else {
               printlog(1, methodname, StringFormat("Orderticket %d ist neu und für das interessante Symbol. Action required.",oticket));
               reduceOrderSize(oticket);
            }
         } 
      }
   }
   printlog(1, methodname, "Ende der Behandlung. Speichere aktuellen Zustand.");
   getCurrentState();
}

bool isExistingTicket(const ulong& tickets[], ulong ticket){
   string methodname="isExistingTicket()";
   bool found=false;
   if (ArraySize(tickets)>0) {
      for (int t=0; t<ArraySize(tickets); t++) {
         if (ticket == tickets[t]) {
            found=true;
            break;
         }
      }
   } else {
      printlog(2, methodname, "Es gab keine tickets zum Durchsuchen.");
   }
   printlog(1, methodname, StringFormat("ticket %d was found: %s", ticket, found));
   
   return found;
}

void reducePositionSize(ulong pticket){
   string methodname="reducePositionSize()";
   PositionSelectByTicket(pticket);
   string psymbol = PositionGetString(POSITION_SYMBOL);
   long   pmagic  = PositionGetInteger(POSITION_MAGIC);
   double psize   = PositionGetDouble(POSITION_VOLUME);
   double volume_step  = SymbolInfoDouble(psymbol, SYMBOL_VOLUME_STEP);
   
   printlog(1, methodname, StringFormat("Position %d für %s eröffnet durch einen EA mit magicNumber %d (0 für manuell), size: %.5f", pticket, psymbol, pmagic, psize));
   double size_to_close_raw = psize * (close_x_percent/100.0);
   int multiplier = (int)(size_to_close_raw / volume_step);
   
   double size_to_close = NormalizeDouble((multiplier * volume_step), (int)SymbolInfoInteger(psymbol,SYMBOL_DIGITS));
   printlog(1, methodname, StringFormat(
     "%s wird in Vielfachen von %.4f gehandelt. Von der Originalpositionsgröße %.4f sollen %.2f Prozent geschlossen werden. Das wären %.4f. Das nächst-niedrige Vielfache von volume_step ist %.4f",
     psymbol, volume_step, psize, close_x_percent, size_to_close_raw, size_to_close));
     
     bool success = trade.PositionClosePartial(pticket, size_to_close, -1);
     if (success) {
        printlog(0,methodname, "Position erfolgreich geändert.");
     } else {
        // evtl. nochmal versuchen oder email schreiben ...
        printlog(0, methodname, StringFormat("Positionsänderung ist fehlgeschlagen, Fehler %d", GetLastError()));
     }

}


void reduceOrderSize(ulong oticket){
   string methodname="reduceOrderSize()";
   if (!OrderSelect(oticket)) {
      printlog(0, methodname, "ERROR: Order konnte nicht ausgewählt werden!");
      return;
   }
   string osymbol = OrderGetString(ORDER_SYMBOL);
   long   omagic  = OrderGetInteger(ORDER_MAGIC);
   double osize   = OrderGetDouble(ORDER_VOLUME_INITIAL);  //CURRENT ... noch nicht gefüllter Anteil
   double oprice  = OrderGetDouble(ORDER_PRICE_OPEN);
   double osl     = OrderGetDouble(ORDER_SL);
   double oslimit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
   ENUM_ORDER_TYPE_TIME oexp = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   long    oexpt   = OrderGetInteger(ORDER_TIME_EXPIRATION);
   double otp     = OrderGetDouble(ORDER_TP);
   double volume_step  = SymbolInfoDouble(osymbol, SYMBOL_VOLUME_STEP);
   
   printlog(1, methodname, StringFormat("Order %d für %s eröffnet durch einen EA mit magicNumber %d (0 für manuell), size: %.5f", oticket, osymbol, omagic, osize));
   double size_to_close_raw = osize * (close_x_percent/100.0);
   int multiplier = int(size_to_close_raw / volume_step);
   
   double size_to_close = NormalizeDouble( (multiplier * volume_step), (int)SymbolInfoInteger(osymbol,SYMBOL_DIGITS));
   printlog(1, methodname, StringFormat(
     "%s wird in Vielfachen von %.4f gehandelt. Von der Originalpositionsgröße %.4f sollen %.2f Prozent geschlossen werden. Das wären %.4f. Das nächst-niedrige Vielfache von volume_step ist %.4f",
     osymbol, volume_step, osize, close_x_percent, size_to_close_raw, size_to_close));
     
     bool success = trade.OrderModify(oticket, oprice, osl, otp, oexp, oexpt, oslimit);
     if (success) {
        printlog(0,methodname, "Order erfolgreich geändert.");
     } else {
        // evtl. nochmal versuchen oder email schreiben ...
        printlog(0, methodname, StringFormat("Order Änderung ist fehlgeschlagen, Fehler %d", GetLastError()));
     }

}