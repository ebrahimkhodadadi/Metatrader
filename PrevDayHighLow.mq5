
#property indicator_chart_window

#property indicator_buffers 2
#property indicator_plots 2

#property indicator_type1 DRAW_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_color1 clrBlue
#property indicator_width1 2
#property indicator_label1 "Prev day high"

#property indicator_type2 DRAW_LINE
#property indicator_style2 STYLE_SOLID
#property indicator_color2 clrRed
#property indicator_width2 2
#property indicator_label2 "Prev day low"

double prevDayHigh[], prevDayLow[];

int OnInit() {
   
   SetIndexBuffer(0, prevDayHigh, INDICATOR_DATA);
   SetIndexBuffer(1, prevDayLow, INDICATOR_DATA);

   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   for(int i = prev_calculated; i < rates_total; i++) {
      int shift = iBarShift(_Symbol, PERIOD_D1, time[i]);
      
      double highD1 = iHigh(_Symbol, PERIOD_D1, shift+1);
      double lowD1 = iLow(_Symbol, PERIOD_D1, shift+1);
      
      prevDayHigh[i] = highD1;
      prevDayLow[i] = lowD1;
   }

   return(rates_total);
}
