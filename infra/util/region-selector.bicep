func getAdjustedRegion(location string, map object) string =>
  map.?overrides[?location] ?? (contains(map.?supportedRegions ?? [], location) ? location : (map.?default ?? location))

// Application Insights region mapping
// Application Insights is available in most regions, but we want to ensure 
// certain regions get mapped to nearby supported regions for optimal performance
var applicationInsightsRegionMap = {
  overrides: {
    eastus2euap: 'eastus2'  // Map EUAP region to standard East US 2
  }
  // No explicit default needed - the getAdjustedRegion function will use the input location as fallback
}

@export()
@description('Based on an intended region, gets an appropriate region for Application Insights.')
func getApplicationInsightsRegion(location string) string => getAdjustedRegion(location, applicationInsightsRegionMap)

// Log Analytics workspace region mapping
// Log Analytics is available in most regions, but we want to ensure 
// certain regions get mapped to nearby supported regions for optimal performance
var logAnalyticsRegionMap = {
  overrides: {
    eastus2euap: 'eastus2'  // Map EUAP region to standard East US 2
  }
  // No explicit default needed - the getAdjustedRegion function will use the input location as fallback
}

@export()
@description('Based on an intended region, gets an appropriate region for Log Analytics workspaces.')
func getLogAnalyticsRegion(location string) string => getAdjustedRegion(location, logAnalyticsRegionMap)
