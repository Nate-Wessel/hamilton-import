# Description
This repository holds the scripts and the data used to generate the files to be imported into OSM per the documentation [on the OSM wiki](https://wiki.openstreetmap.org/wiki/Hamilton_County_Building_Import). 

# Workflow
The original CAGIS data as provided in `/original_data` (recompressed for size) comes as two shapefiles. These were imported into a local PostGIS database using e.g. the following commands:

`shp2pgsql -s 3735:4326 -g geom -I parcels.shp | psql -d cagis`

`shp2pgsql -s 3735:4326 -g geom -I buildings.shp | psql -d cagis`

...reprojecting them into `epsg:4326`.

Download fresh OSM data and pull it into PostGIS as well using e.g. ` osm2pgsql -d osm -c --prefix ham --slim --extra-attributes --hstore --latlong ham-cou.osm`.

We then run the `conflation.sql` PostGIS script which 

* checks for intersections between the building dataset and buildings in OSM
* derives addresses from the parcel dataset where possible
* exports the relavant attributes to separate tables with very slightly simplified geometries

More detail on the process is provided on the OSM wiki page and in code comments. 

We now have two PostGIS tables, one for buildings that need to be conflated manually with buildings in OSM, and one for buildings that can be imported more neatly. 

...

More to come on turning these into a format appropriate for the tasking manager. 
