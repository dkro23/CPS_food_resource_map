#
# This is the server logic of a Shiny web application. You can run the 
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
# 
#    http://shiny.rstudio.com/
#

#######
### Shiny Server.R
### Resource map with CPS school locations for serving food
### Code reference: https://github.com/atmajitg/bloodbanks/blob/master/ui.R
### Geocode reference: https://www.r-bloggers.com/4-tricks-for-working-with-r-leaflet-and-shiny/
### Data reference: See Trello card
######


### Load Packages

library(shiny)
library(RCurl)
library(dplyr)
library(leaflet)
library(DT)
library(ggmap)
library(shinyjs)
library(readxl)
library(raster)
library(sp)
library(rgdal)
library(sf)
library(rgeos)

library(highcharter)



### Geocoding

# Register

register_google("<YOUR KEY>")

### Function allowing geolocalisation

jsCode <- '
shinyjs.geoloc = function() {
navigator.geolocation.getCurrentPosition(onSuccess, onError);
function onError (err) {
Shiny.onInputChange("geolocation", false);
}
function onSuccess (position) {
setTimeout(function () {
var coords = position.coords;
console.log(coords.latitude + ", " + coords.longitude);
Shiny.onInputChange("geolocation", true);
Shiny.onInputChange("lat", coords.latitude);
Shiny.onInputChange("long", coords.longitude);
}, 5)
}
};
'

### Load Data w/ Github

x<-getURL("https://raw.githubusercontent.com/dkro23/CPS_food_map/master/schools_sy1920.csv")
school_data<-read.csv(text=x)
head(school_data)
names(school_data)

### Shiny Server

shinyServer(function(input, output) {
  # Import Data and clean it
  
  school_data <- data.frame(school_data)
  school_data$Latitude <-  as.numeric(as.character(school_data$Y))
  school_data$Longitude <-  as.numeric(as.character(school_data$X))
  school_data=filter(school_data, school_data$Latitude != "NA") # removing NA values
  
  # new column for the popup label
  
  school_data <- mutate(school_data, cntnt=paste0('<strong>School Name: </strong>',School_Nm,
                                              '<br><strong>School ID:</strong> ', School_ID,
                                              '<br><strong>Address:</strong> ', Sch_Addr,
                                              '<br><strong>Grades:</strong> ',Grades,
                                              '<br><strong> Is this school serving food during Spring Break?</strong> ', serving_spr,
                                              '<br><strong> Is this school serving food after Spring Break?</strong> ', serving_after))
  
  # new column for categories of food serving type
  
  school_data <- mutate(school_data,type=ifelse(serving_spr=="No",ifelse(serving_after=="Yes","Only After Spring Break","Not Serving at all"),
                                                ifelse(serving_after=="Yes","Serving During Spring Break and After","Only During Spring Break")))
  
  # create a color paletter for category type in the data file
  
  pal <- colorFactor(palette  = c("red", "blue", "yellow","green"), 
                     domain = school_data$type)
  
  # HOLD

 
  # create the leaflet map with action button and search bar
  
  ur_address<-eventReactive(input$goButton,{
    as.character(input$target_zone)
  },ignoreNULL = F)
  
  output$cps_food_map <- renderLeaflet({
      
      # Get latitude and longitude
      
      if(ur_address()=="Millennium Park"){
        ZOOM=11
        LAT=41.882708
        LONG=-87.622667
      }else{
        
        target_pos=geocode(ur_address())
        LAT=target_pos$lat
        LONG=target_pos$lon
        ZOOM=18
      }
    
      #
    
      
      
      #
      leaflet(school_data) %>% 
        addCircles(lng = ~Longitude, lat = ~Latitude) %>% 
        addTiles() %>%
        addCircleMarkers(data = school_data, lat =  ~Latitude, lng =~Longitude, 
                         radius = 7, popup = ~as.character(cntnt), 
                         color = ~pal(type),
                         stroke = FALSE, fillOpacity = 0.8,
                         clusterOptions = markerClusterOptions())%>%
        
        addLegend(pal=pal, values=~type,opacity=1, na.label = "Not Available")%>%
        
        
        setView(lng=LONG, lat=LAT, zoom=ZOOM ) %>%
        
        addEasyButton(easyButton(
          icon="fa-crosshairs", title="ME",
          onClick=JS("function(btn, map){ map.locate({setView: true}); }")))
        
        
    })
  
  
  
 

  
  
  # create a data object to display data
  
  output$data <-DT::renderDataTable(datatable(
    school_data[,c(4,3,5,6,7,8,11,12)],filter = 'top',
    colnames = c("School Name","School ID","Address","Grade Category","Grades","School Type","Serving Spring Break?","Serving After Spring Break")
  ))
  
  # Find geolocalisation coordinates when user clicks
  observeEvent(input$geoloc, {
    js$geoloc()
  })
  
  
  # zoom on the corresponding area
  observe({
    if(!is.null(input$lat)){
      map <- leafletProxy("map")
      dist <- 0.2
      lat <- input$lat
      lng <- input$long
      map %>% fitBounds(lng - dist, lat - dist, lng + dist, lat + dist)
    }
  })
  
  
  
  # Create list of closest schools
  
  #observeEvent(input$target_zone,{
  #gdis <- pointDistance(cbind(LONG,LAT),cbind(school_data$Longitude,school_data$Latitude), lonlat=TRUE,allpairs = T)
  #top5_num<-sort(gdis)[1:5]
  #top5_names<-c()
  #for (i in c(1:5)){
  #  d<-grep(top5[i],gdis)
  #  top5_names[i]<-as.character(school_data$School_Nm[d])
  #}
  
  #output$close_schools<-renderText(top5_names)
    
  #})
  
  
})
