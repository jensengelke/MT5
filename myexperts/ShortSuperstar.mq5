//+------------------------------------------------------------------+
//|                                               ShortSuperstar.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include<Trade\Trade.mqh>

datetime lastCandleOpenTime = NULL;
CTrade trade;


input    double   min_distrance          = 20.0;
input    double   size                   = 0.25;
input    double   stoploss               = 70.0;
input    int      loglevel               = 2; 
input    int      myMagic                = 20231003;



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   trade.SetExpertMagicNumber(myMagic);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   string methodname = "OnTick()";
   if (iTime(_Symbol, PERIOD_M30, 0) == lastCandleOpenTime) return;
   lastCandleOpenTime=iTime(_Symbol, PERIOD_M30, 0);
   
   printlog(2,methodname, "processing new M30 candle"); 
   
   MqlDateTime todayStruct;
   TimeCurrent(todayStruct);
   
   if (todayStruct.hour < 9) return; //nothing to do before market opens
   
   ulong orderTicket = -1;
   if (OrdersTotal()>0) {
      for (int o=OrdersTotal(); o >= 0; o--) {
         OrderGetTicket(o); // select order
         int orderMagic = OrderGetInteger(ORDER_MAGIC);
         if (orderMagic != myMagic) {
            printlog(2,methodname, StringFormat("order with magic %i", orderMagic));
            continue;
         }
        
         datetime orderTime = OrderGetInteger(ORDER_TIME_SETUP);
         MqlDateTime orderTimeStruct;
         TimeToStruct(orderTime, orderTimeStruct);
         printlog(2, methodname, StringFormat("There is an order from %i, cancelling due to age.", orderTimeStruct.day));
         if (orderTimeStruct.day != todayStruct.day) {
            int orderState = OrderGetInteger(ORDER_STATE);
            printlog(2, methodname, StringFormat("old order with ticket %i in state %i", OrderGetInteger(ORDER_TICKET), orderState));
            trade.OrderDelete(OrderGetInteger(ORDER_TICKET));
            continue;
         } //skip old orders
         
            
         orderTicket = OrderGetInteger(ORDER_TICKET);
         printlog(2, methodname,  StringFormat("setting ticket to %i", orderTicket));
         break;
      }
   }
   
   if (orderTicket != -1) return; //nothing to do, if there is an existing order.
   
   //  calculate today's open 
   todayStruct.hour = 9;
   todayStruct.min = 0;
   datetime todayOpen = StructToTime(todayStruct);
   
   ulong positionTicket = -1;
   if (PositionsTotal() > 0) {
      for (int p = PositionsTotal(); p >=0 ; p--) {
         PositionGetTicket(p);
         if (PositionGetInteger(POSITION_MAGIC) != myMagic) continue;
         positionTicket = PositionGetInteger(POSITION_TICKET);
         
         // exit logic         
         datetime positionOpenTime = PositionGetInteger(POSITION_TIME);
         MqlDateTime positionOpenTimeStruct;
         TimeToStruct(positionOpenTime, positionOpenTimeStruct);
         if ( positionOpenTimeStruct.day != todayStruct.day) { // no stop on day 1
            
            if (PositionGetDouble(POSITION_SL) == 0.0) {
               // TODO close immediately, if price is more than 70 points higher
               double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double sl = NormalizeDouble( positionOpenPrice + stoploss, _Digits);
               trade.PositionModify(positionTicket, sl, 0.0);
               
            }
            
            //Is it 2 trading days later?
            datetime twoDaysBefore = iTime(_Symbol,PERIOD_D1, 2);
            MqlDateTime twoDaysBeforeStruct;
            TimeToStruct(twoDaysBefore, twoDaysBeforeStruct);
            printlog(1, methodname, StringFormat("Position was opened on %i, two days before today was %i", positionOpenTimeStruct.day, twoDaysBeforeStruct.day));
            
            if (TimeCurrent() >= todayOpen && positionOpenTimeStruct.day <= twoDaysBeforeStruct.day ) {
               trade.PositionClose(positionTicket, -1);
            }
         }         
      }
   }
   if (positionTicket != -1) return; //nothing to do, if there is an existing position.
   
   
   
   int barShiftTodayOpen = iBarShift(_Symbol, PERIOD_M1, todayOpen, true);
   double todayOpenPrice = iOpen(_Symbol, PERIOD_M1, barShiftTodayOpen);
   
   printlog(2, methodname, StringFormat("Today's open time: %s, open was at %.2f", TimeToString(todayOpen), todayOpenPrice));
   
   // calculate yesterday's high
   
   datetime previousTradingDay = iTime(_Symbol,PERIOD_D1,1);
   MqlDateTime previousTradingDayStruct;
   TimeToStruct(previousTradingDay, previousTradingDayStruct);
   printlog(2, methodname, StringFormat("prev trading day: %d", previousTradingDayStruct.day)); 
   
   previousTradingDayStruct.hour=9;
   previousTradingDayStruct.min=0;
   datetime lastTradingDayOpen = StructToTime(previousTradingDayStruct);
   
   previousTradingDayStruct.hour=17;
   previousTradingDayStruct.min=30;
   datetime lastTradingDayClose = StructToTime(previousTradingDayStruct);   
   
   int barShiftOpen = iBarShift(_Symbol, PERIOD_M30, lastTradingDayOpen, true);
   int barShiftClose = iBarShift(_Symbol, PERIOD_M30, lastTradingDayClose, true);
   
   double high = iHigh(_Symbol, PERIOD_M30, iHighest(_Symbol, PERIOD_M30, MODE_HIGH, (barShiftOpen - barShiftClose) , barShiftClose));
   
   printlog(1, methodname, StringFormat("open: %d, close %d, current time %s, last trading day high: %.2f", barShiftOpen, barShiftClose, TimeToString(TimeCurrent()), high));
      
   ObjectDelete(0,"short-superstar-high" );
   ObjectCreate(0, "short-superstar-high", OBJ_HLINE, 0, 0, high );
   
   if ( todayOpenPrice - min_distrance > high ) { // today's open is more than x points (20 by default) above yesterday's high
      
      datetime todayClose = StringToTime("17:30");
      printlog(2, methodname, StringFormat("opening order with expiration at %s", TimeToString(todayClose)));
      
      trade.SellStop( 
         size, 
         NormalizeDouble(high, _Digits),
         _Symbol,
         0.0, 
         0.0, 
         ORDER_TIME_SPECIFIED, 
         todayClose,
         "Short Superstar"
      );
   }
   
   
 }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+


void printlog(int level, string methodname, string message) {
   if (level <= loglevel) {
      PrintFormat("%i %s %s", level, methodname, message);
   }
}
