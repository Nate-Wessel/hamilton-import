# Description
This repository holds the scripts and the data used to generate the files to be imported into OSM per the documentation [on the OSM wiki](https://wiki.openstreetmap.org/wiki/Hamilton_County_Building_Import). 

# Workflow
The original CAGIS data as provided in `/original_data` (recompressed for size) comes as two shapefiles. These were imported into a local PostGIS database using e.g. the following commands:

`shp2pgsql -s 3735:4326 -g geom -I parcels.shp | psql -d cagis`

`shp2pgsql -s 3735:4326 -g geom -I buildings.shp | psql -d cagis`

...reprojecting them into `epsg:4326`.
