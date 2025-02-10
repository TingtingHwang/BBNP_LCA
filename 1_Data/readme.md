# Data description
The dataset includes the following **7 geospatial layers** (processed into aligned GeoTIFF format (ISO 19115-33 compliant) formats):  
- **Altitude**: Sourced from [NASA EARTHDATA](https://earthdata.nasa.gov/).  
- **Geology**: Sourced from [BGS Geology](https://www.bgs.ac.uk/).  
- **Historic**: Sourced from [Landmap](https://www.landmap.ac.uk/).  
- **Landcover**: Sourced from [Living Wales](https://livingwales.uk/).  
- **Landform**: Sourced from [Landmap](https://www.landmap.ac.uk/).  
- **Soilscape**: Sourced from [UK Soil Observatory](https://www.ukso.org/).  
- **Vegetation**: Sourced from [Living Wales](https://livingwales.uk/).  

All the data are projected into the same coordinate system (British_National_Grid) and then resampled using the Nearest Neighbour method to achieve a uniform 30 m pixel resolution  via ArcGIS.

