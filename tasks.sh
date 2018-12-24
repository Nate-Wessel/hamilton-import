FILES=/home/nate/tasks/*.shp
for f in $FILES
do
	echo "Processing $f"
	python ~/scripts/ogr2osm/ogr2osm.py $f -t ~/hamilton-import/ogr2osm_config.py
done
