-- add fields for OSM tags and data processing 
ALTER TABLE buildings 
	ADD COLUMN "addr:housenumber" text,
	ADD COLUMN "addr:street" text,
	ADD COLUMN "name" text,
	ADD COLUMN "height" int,
	ADD COLUMN "building:levels" smallint,
	ADD COLUMN "building:levels:underground" smallint,
	ADD COLUMN loc_geom geometry(multipolygon,32616),
	ADD COLUMN conflated boolean DEFAULT FALSE,
	ADD COLUMN main boolean; -- is it the main building on the parcel?

-- create local geometry fields and validate geometries
UPDATE buildings SET loc_geom = ST_MakeValid(ST_Transform(geom,32616));
CREATE INDEX ON buildings USING GIST (loc_geom);

-- identify intersecting/conflated buildings
UPDATE buildings AS b SET conflated = TRUE 
FROM ham_polygon AS osm
	WHERE ST_Intersects(b.geom,osm.way)
	AND osm.building IS NOT NULL and osm.building != 'no';



-- added fields for the parcels table
ALTER TABLE parcels 
	ADD COLUMN loc_geom geometry(multipolygon,32616),
	ADD COLUMN repeating BOOLEAN DEFAULT FALSE;

-- create local geometry fields and validate geometries
UPDATE parcels SET loc_geom = ST_MakeValid(ST_Transform(geom,32616));
CREATE INDEX ON parcels USING GIST (loc_geom);

-- identify repeating parcels (indicates multiple addresses associated with buildings)
WITH geom_counts AS (
	SELECT array_agg(gid) AS ids, COUNT(*)
	FROM parcels 
	GROUP BY geom
), geom_counts2 AS (
	SELECT * FROM geom_counts WHERE count > 1
)
UPDATE parcels SET repeating = TRUE
FROM geom_counts2 
WHERE ids @> ARRAY[gid];



-- attempt to identify garages and sheds so they don't get addresses
UPDATE buildings SET main = NULL;
-- sort the buildings on each parcel by size
WITH sizes AS (
	SELECT 
		p.gid AS pid, 
		b.gid AS bid,
		row_number() OVER ( PARTITION BY p.gid ORDER BY ST_Area(b.loc_geom) DESC) AS size_order
	FROM buildings AS b JOIN parcels AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE NOT p.repeating
	ORDER BY p.gid ASC
) UPDATE buildings SET main = CASE 
	WHEN size_order = 1 THEN TRUE
	WHEN size_order > 1 THEN FALSE
	ELSE NULL
END
FROM sizes WHERE sizes.bid = buildings.gid;
-- any building not properly intersecting one main parcel gets a NULL here


-- get address information into the buildings table
UPDATE buildings SET "addr:housenumber" = NULL;
WITH addresses AS (
	SELECT 
		b.gid,
		array_to_string( ARRAY_AGG(DISTINCT addrno), ';') AS housenumber
	FROM buildings AS b JOIN parcels AS p ON 
		ST_Intersects(b.loc_geom,p.loc_geom) AND
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	GROUP BY b.gid
)
UPDATE buildings AS b SET "addr:housenumber" = housenumber
FROM addresses AS a
WHERE 
	a.gid = b.gid AND 
	main AND -- is main building
	sqft > 900;

