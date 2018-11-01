-- add fields for OSM tags and data processing 
ALTER TABLE buildings 
	ADD COLUMN "addr:housenumber" text,
	ADD COLUMN "addr:street" text,
	ADD COLUMN loc_geom geometry(multipolygon,32616),
	ADD COLUMN conflated boolean DEFAULT FALSE,
	ADD COLUMN main boolean; -- is it the main building on the parcel?

-- create local geometry fields and validate geometries
UPDATE buildings SET loc_geom = ST_MakeValid(ST_Transform(geom,32616));
CREATE INDEX ON buildings USING GIST (loc_geom);

-- added fields for the parcels table
ALTER TABLE parcels 
	ADD COLUMN "addr:street" text,
	ADD COLUMN loc_geom geometry(multipolygon,32616),
	ADD COLUMN building_count integer,
	ADD COLUMN repeating BOOLEAN DEFAULT FALSE;

-- create local geometry fields and validate geometries
UPDATE parcels SET loc_geom = ST_MakeValid(ST_Transform(geom,32616));
CREATE INDEX ON parcels USING GIST (loc_geom);

-- parse and expand parcel street addresses
UPDATE parcels SET "addr:street" = initcap(addrst)||' '||
	CASE 
		WHEN upper(addrsf) = 'AV' THEN 'Avenue'
		WHEN upper(addrsf) = 'DR' THEN 'Drive'
		WHEN upper(addrsf) = 'RD' THEN 'Road'
		WHEN upper(addrsf) = 'ST' THEN 'Street'
		WHEN upper(addrsf) = 'LN' THEN 'Lane'
		WHEN upper(addrsf) = 'CT' THEN 'Court'
		WHEN upper(addrsf) = 'PL' THEN 'Place'
		WHEN upper(addrsf) = 'CR' THEN 'Circle'
		WHEN upper(addrsf) = 'TE' THEN 'Terrace'
		WHEN upper(addrsf) = 'PK' THEN 'Park'
		WHEN upper(addrsf) = 'WY' THEN 'Way'
		WHEN upper(addrsf) = 'BV' THEN 'Boulevard'
		WHEN upper(addrsf) = 'PW' THEN 'Parkway'
		WHEN upper(addrsf) = 'TL' THEN 'Trail'
		WHEN upper(addrsf) = 'HW' THEN 'Highway'
		WHEN upper(addrsf) = 'WA' THEN 'Way'
		WHEN upper(addrsf) = 'TR' THEN 'Terrace'
		WHEN upper(addrsf) = 'SQ' THEN 'Square'
		WHEN upper(addrsf) = 'AL' THEN 'Alley'
		WHEN upper(addrsf) = 'BL' THEN 'Boulevard'
		WHEN upper(addrsf) = 'CI' THEN 'Circle'
		WHEN upper(addrsf) = 'PT' THEN 'Point'
		WHEN upper(addrsf) = 'PI' THEN 'Pike'
		WHEN upper(addrsf) = 'LA' THEN 'Lane'
		ELSE '' -- NULL cases mostly have the suffix in the name field
	END;


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


-- identify parcels with multiple buildings
UPDATE parcels SET building_count = NULL WHERE building_count IS NOT NULL;
WITH bcounts AS (
	SELECT 
		p.gid, COUNT(*)
	FROM buildings AS b JOIN parcels AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	GROUP BY p.gid
)
UPDATE parcels SET building_count = count
FROM bcounts WHERE bcounts.gid = parcels.gid;


-- add addresses to buildings with simple 1:1 matches to parcels
UPDATE buildings SET "addr:housenumber" = NULL, "addr:street" = NULL;
WITH a AS (
	SELECT 
		b.gid, p.addrno, p."addr:street"
	FROM buildings AS b JOIN parcels AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE p.building_count = 1 AND NOT p.repeating
)
UPDATE buildings SET 
	"addr:housenumber" = a.addrno,
	"addr:street" = a."addr:street"
FROM a WHERE buildings.gid = a.gid;

--SELECT COUNT(*) FROM buildings WHERE "addr:housenumber" IS NOT NULL OR "addr:street" IS NOT NULL;

-- attempt to identify garages and sheds so they don't get addresses
UPDATE buildings SET main = NULL;
-- sort the buildings on each parcel by size, but only where it's likely a garage/shed situation
WITH sizes AS (
	SELECT 
		p.gid AS pid, 
		b.gid AS bid,
		row_number() OVER ( PARTITION BY p.gid ORDER BY ST_Area(b.loc_geom) DESC) AS size_order
	FROM buildings AS b JOIN parcels AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE 
		NOT p.repeating AND -- single parcels
		p.building_count IN (2,3) -- 2 or 3 buildings on parcel
	ORDER BY p.gid ASC
) UPDATE buildings SET main = CASE 
	WHEN size_order = 1 THEN TRUE
	WHEN size_order > 1 THEN FALSE
	ELSE NULL
END
FROM sizes WHERE sizes.bid = buildings.gid;

-- now assign addresses to main buildings on parcels with outbuildings
WITH a AS (
	SELECT 
		b.gid, p.addrno, p."addr:street"
	FROM buildings AS b JOIN parcels AS p ON
		ST_Intersects(b.loc_geom,p.loc_geom) AND 
		ST_Area(ST_Intersection(b.loc_geom,p.loc_geom)) > 0.9*ST_Area(b.loc_geom)
	WHERE 
		p.building_count IN (2,3)
		AND NOT p.repeating 
		AND b.main -- is main building
)
UPDATE buildings SET 
	"addr:housenumber" = a.addrno,
	"addr:street" = a."addr:street"
FROM a WHERE buildings.gid = a.gid;







/*


-- get address information into the buildings table for all buildings
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
	a.gid = b.gid;


-- identify intersecting/conflated buildings
UPDATE buildings AS b SET conflated = TRUE 
FROM ham_polygon AS osm
	WHERE ST_Intersects(b.geom,osm.way)
	AND osm.building IS NOT NULL and osm.building != 'no';
*/