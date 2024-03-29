#property copyright "Copyright 2023, DerJens"
#property link      "https://www.mql5.com"
#property version   "1.00"
#include<Trade\Trade.mqh>

input string symbol_to_cancel = "GOLD";
input double close_x_percent = 100.0;
input int    myMagic = 20231006;

ulong last_ticket_processed = -1;
CTrade *trade = new CTrade();

int OnInit() {
   int result = INIT_SUCCEEDED;
   if (close_x_percent < 0 || close_x_percent > 100)  {
      result = INIT_PARAMETERS_INCORRECT;
      PrintFormat("close_x_percent muss zwischen 0.0 und 100.0 liegen.");
   }
   trade.SetExpertMagicNumber(myMagic);
   return(result);
  }

void OnTrade() { //MarketOrders können scheinbar nicht bearbeitet werden :-( also muss die Position sofort geschlossen werden
     
   if (PositionsTotal() > 0) {
      for (int p = PositionsTotal() - 1; p>=0; p--) { // die Liste der aktuellen Positionen von hinten nach vorn durchgehen.
         ulong  pos_ticket = PositionGetTicket(p); //aktuelle Position aus der Liste "in den Kontext" wählen
         string pos_symbol = PositionGetString(POSITION_SYMBOL);
         long   pos_magic  = PositionGetInteger(POSITION_MAGIC);
         double pos_size   = PositionGetDouble(POSITION_VOLUME);
         double volume_step  = SymbolInfoDouble(pos_symbol, SYMBOL_VOLUME_STEP);
         
         PrintFormat("Position %d für %s eröffnet durch einen EA mit magicNumber %d (0 für manuell), size: %.5f", pos_ticket, pos_symbol, pos_magic, pos_size);
         double size_to_close_raw = pos_size * (close_x_percent/100.0);
         int multiplier = size_to_close_raw / volume_step;
         
         double size_to_close = NormalizeDouble( (multiplier * volume_step), SymbolInfoInteger(symbol_to_cancel,SYMBOL_DIGITS));
         
         PrintFormat("ticksize: %.5f, size to close: %.5f, nearest multiple of volume_step: %.5f", volume_step, size_to_close_raw, size_to_close);
         if (pos_symbol == symbol_to_cancel && pos_ticket != last_ticket_processed) { // hier müsste noch die magic number geprüft werden
            bool success = trade.PositionClosePartial(pos_ticket, size_to_close, -1);
             // trade.PositionClose(pos_ticket, -1); // -1: keine Einschränkung bei der slippage
            if (success) {
               PrintFormat("Position erfolgreich geschlossen.");
               last_ticket_processed = pos_ticket;
            } else {
               // evtl. nochmal versuchen oder email schreiben ...
               PrintFormat("Position schließen is fehlgeschlagen, Fehler %d", GetLastError());
            }
         }  // Ende "ja, ich muss löschen"         
      } // Ende Positionsschleife
   } // Ende OnTrade())
 }  
