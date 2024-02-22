
#property indicator_chart_window

#property indicator_buffers 1
#property indicator_plots 1

#property indicator_type1 DRAW_LINE
#property indicator_style1 STYLE_SOLID
#property indicator_color1 clrBlue
#property indicator_width1 2
#property indicator_label1 "close"

double closeBar[];

input string closeTime = "23:30:00";

int OnInit()
{
   SetIndexBuffer(0, closeBar, INDICATOR_DATA);

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
      MqlDateTime todayDateTime;
      TimeToStruct(time[i], todayDateTime);
      
      datetime yesterday = time[i] - 60 * 60 * 24;
      MqlDateTime yesterdayDateTime;
      TimeToStruct(yesterday,yesterdayDateTime);
      datetime lastDateTime = StringToTime(yesterdayDateTime.year + "/" + yesterdayDateTime.mon + "/" + (yesterdayDateTime.day) + " " + closeTime);
      
      //if(todayDateTime.hour > 23 || (todayDateTime.hour < 1))
      //   closeBar[i] = NULL;
         
      int shift = iBarShift(_Symbol, PERIOD_M1, lastDateTime);
      closeBar[i] = iClose(_Symbol, PERIOD_M1, shift);
   }
   
   return(rates_total);
}
