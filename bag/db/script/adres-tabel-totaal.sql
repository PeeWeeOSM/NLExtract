/*
-- Dit script is gemaakt door Peter van Wee (github: PeeWeeOSM )

Resultaat van dit script is de tabel "adres_totaal"

Het script bevat alle "adressen" van de adres_plus tabel aangevuld met alle adressen uit de BAG die ooit "bestaan" hebben of nog moeten worden gerealiseerd.
Onder een adres wordt verstaan de unieke combinatie van: openbareruimte_id, postcode, huisnummer, huisletter, huisnummertoevoeging 
Een adres wordt pas beschouwd als er gerelateerde records zijn in de tabel nummeraanduiding, adresseerbaarobject (VBO,STA,LIG), openbare ruimte, woonplaats, gemeente
Van zo'n adres is maar 1 voorkomen aanwezig in deze tabel.

Hier zitten dan ook adressen tussen waarvan de status van het verblijfsobject "Niet gerealiseerd verblijfsobject" of "Verblijfsobject ingetrokken" kunnen zijn.
Dus adressen die bestaan, hebben bestaan, foutief ingevoerd of wellicht nog gerealiseerd moeten worden maar nooit dubbele adressen.

Het betreft een aanvulling op adres_plus in de zin dat het meer records zijn. Alle records van adres_plus krijgen als kenmerk "actueel" voor het attribuut "adres_status". 
Alle adressen die niet voorkomen in adres_plus hebben hiervoor het kenmerk "historisch of toekomstig".

Het aantal attributen van adres_totaal is minder dan van adres_plus omdat bv type huis niet af te leiden is als alle historische/toekomstige data meegenomen wordt. 

*/


SET search_path TO bagactueel,public;

-- stel alle unique "adressen" vast die historisch gezien in de BAG zijn opgenomen. Voorwaarde is dat er een NAD en bijbehorend VBO, of LIG of STA is.
drop table if exists adresselectie_tot;
create table adresselectie_tot as 
SELECT 
distinct
coalesce(NAD.postcode,'0') ||'-'||NAD.huisnummer::text||'-'|| coalesce(NAD.huisletter, '0')||'-'|| coalesce(NAD.huisnummertoevoeging, '0') as PCHNHLHT,
coalesce(NAD.postcode,'0') ||'-'||NAD.huisnummer::text||'-'|| coalesce(NAD.huisletter, '0')||'-'|| coalesce(NAD.huisnummertoevoeging, '0')||'-'||  NAD.gerelateerdeopenbareruimte as uniq_key,
case when NAD.postcode is null then  null else 1 end pchn_UNIEK,
case when NAD.postcode is null then null else 1 end pchnhlht_UNIEK,
NAD.identificatie as NAD_ID, 
--OBR.openbareruimtenaam, 
--OBR.verkorteopenbareruimtenaam, 
--OBR.openbareruimtetype,
NAD.huisnummer, 
NAD.huisletter, 
NAD.huisnummertoevoeging, 
NAD.postcode, 

0 as Nevenadres,
NAD.nummeraanduidingstatus, 
NAD.typeadresseerbaarobject, 
Case 
when VBO.identificatie is not null then 'VBO'
when LIG.identificatie is not null then 'LIG'
when STA.identificatie is not null then 'STA' 
end typeadresseerbaarobjectkort, 
NAD.gerelateerdeopenbareruimte as OBR_ID,
NAD.begindatumtijdvakgeldigheid as NAD_BEGIN,
NAD.einddatumtijdvakgeldigheid as NAD_EIND, 
coalesce( VBO.begindatumtijdvakgeldigheid ,LIG.begindatumtijdvakgeldigheid, STA.begindatumtijdvakgeldigheid) as ADRESSEERBAAROBJECT_BEGIN,
coalesce( VBO.einddatumtijdvakgeldigheid ,LIG.einddatumtijdvakgeldigheid, STA.einddatumtijdvakgeldigheid) as ADRESSEERBAAROBJECT_EIND,
coalesce( VBO.inonderzoek ,LIG.inonderzoek, STA.inonderzoek) as ADRESSEERBAAROBJECT_inonderzoek,
coalesce(VBO.identificatie ,   LIG.identificatie, STA.identificatie) as adresseerbaarobject_id,
Coalesce (  VBO.verblijfsobjectstatus::text,  LIG.ligplaatsstatus::text,   STA.standplaatsstatus::text) as adresseerbaarobject_status,
coalesce(round(cast(ST_Area(ST_Transform(sta.geovlak,28992) )as numeric),0),    round(cast(ST_Area(ST_Transform(lig.geovlak,28992) )as numeric),0),VBO.oppervlakteverblijfsobject) as opp_adresseerbaarobject_m2,
--0 as aantal_NAD_per_Adresobject,
coalesce (  vbo.geopunt, ST_Force3D(ST_Centroid(lig.geovlak)) ,ST_Force3D(ST_Centroid(sta.geovlak)) )   as geopunt,
--coalesce (  lig.geovlak,sta.geovlak )   as geovlak,
coalesce ( ST_X(vbo.geopunt), ST_X(ST_Force3D(ST_Centroid(lig.geovlak))),ST_X(ST_Force3D(ST_Centroid(sta.geovlak)))) as X,
coalesce ( ST_Y(vbo.geopunt), ST_Y(ST_Force3D(ST_Centroid(lig.geovlak))),ST_Y(ST_Force3D(ST_Centroid(sta.geovlak)))) as Y,
-- ROUND(cast(avg(ST_x (ST_Transform (geopunt, 4326)))as numeric),3) as lon,
ROUND(cast(coalesce ( ST_X(ST_Transform(vbo.geopunt, 4326)),ST_X(ST_Transform(ST_Force3D(ST_Centroid(lig.geovlak)), 4326)), ST_X(ST_Transform(ST_Force3D(ST_Centroid(sta.geovlak)), 4326))) as numeric),6) as lon,
ROUND(cast(coalesce ( ST_Y(ST_Transform(vbo.geopunt, 4326)),ST_Y(ST_Transform(ST_Force3D(ST_Centroid(lig.geovlak)), 4326)), ST_Y(ST_Transform(ST_Force3D(ST_Centroid(sta.geovlak)), 4326))) as numeric),6) as lat
FROM 
nummeraanduidingactueel NAD
left outer join   verblijfsobjectactueel VBO
on    NAD.identificatie  =VBO.hoofdadres 
left outer join  standplaatsactueel STA
on NAD.identificatie =  STA.hoofdadres 
left outer join  ligplaatsactueel LIG
on NAD.identificatie = LIG.hoofdadres 
WHERE 
(VBO.hoofdadres is not null or   STA.hoofdadres is not null or   LIG.hoofdadres is not null) 


union
-- De actueelbestaand tabellen van NEV< NAD, LIG, STA en VBO joinen (= nevenadressen)

SELECT 
distinct
coalesce(NAD.postcode,'0')||'-'||NAD.huisnummer::text||'-'|| coalesce(NAD.huisletter, '0')||'-'|| coalesce(NAD.huisnummertoevoeging, '0') as PCHNHLHT,
coalesce(NAD.postcode,'0') ||'-'||NAD.huisnummer::text||'-'|| coalesce(NAD.huisletter, '0')||'-'|| coalesce(NAD.huisnummertoevoeging, '0')|| '-'|| NAD.gerelateerdeopenbareruimte as uniq_key,
case when NAD.postcode is null then  null else 1 end pchn_UNIEK,
case when NAD.postcode is null then null else 1 end pchnhlht_UNIEK,
NAD.identificatie as NAD_ID, 

NAD.huisnummer, 
NAD.huisletter, 
NAD.huisnummertoevoeging, 
NAD.postcode, 

1 as Nevenadres,
NAD.nummeraanduidingstatus, 
NAD.typeadresseerbaarobject, 
Case 
when VBO.identificatie is not null then 'VBO'
when LIG.identificatie is not null then 'LIG'
when STA.identificatie is not null then 'STA' 
end typeadresseerbaarobjectkort, 
NAD.gerelateerdeopenbareruimte as OBR_ID,
NAD.begindatumtijdvakgeldigheid as NAD_BEGIN,
NAD.einddatumtijdvakgeldigheid as NAD_EIND, 
coalesce( VBO.begindatumtijdvakgeldigheid ,LIG.begindatumtijdvakgeldigheid, STA.begindatumtijdvakgeldigheid) as ADRESSEERBAAROBJECT_BEGIN,
coalesce( VBO.einddatumtijdvakgeldigheid ,LIG.einddatumtijdvakgeldigheid, STA.einddatumtijdvakgeldigheid) as ADRESSEERBAAROBJECT_EIND,
coalesce( VBO.inonderzoek ,LIG.inonderzoek, STA.inonderzoek) as ADRESSEERBAAROBJECT_inonderzoek,
coalesce(VBO.identificatie ,   LIG.identificatie, STA.identificatie) as adresseerbaarobject_id,
Coalesce (  VBO.verblijfsobjectstatus::text,  LIG.ligplaatsstatus::text,   STA.standplaatsstatus::text) as adresseerbaarobject_status,
coalesce(round(cast(ST_Area(ST_Transform(sta.geovlak,28992) )as numeric),0),    round(cast(ST_Area(ST_Transform(lig.geovlak,28992) )as numeric),0),VBO.oppervlakteverblijfsobject) as opp_adresseerbaarobject_m2,
--0 as aantal_NAD_per_Adresobject,
coalesce (  vbo.geopunt, ST_Force3D(ST_Centroid(lig.geovlak)) ,ST_Force3D(ST_Centroid(sta.geovlak)) )   as geopunt,
--coalesce (  lig.geovlak,sta.geovlak )   as geovlak,
coalesce ( ST_X(vbo.geopunt), ST_X(ST_Force3D(ST_Centroid(lig.geovlak))),ST_X(ST_Force3D(ST_Centroid(sta.geovlak)))) as X,
coalesce ( ST_Y(vbo.geopunt), ST_Y(ST_Force3D(ST_Centroid(lig.geovlak))),ST_Y(ST_Force3D(ST_Centroid(sta.geovlak)))) as Y,
ROUND(cast(coalesce ( ST_X(ST_Transform(vbo.geopunt, 4326)),ST_X(ST_Transform(ST_Force3D(ST_Centroid(lig.geovlak)), 4326)), ST_X(ST_Transform(ST_Force3D(ST_Centroid(sta.geovlak)), 4326))) as numeric),6) as lon,
ROUND(cast(coalesce ( ST_Y(ST_Transform(vbo.geopunt, 4326)),ST_Y(ST_Transform(ST_Force3D(ST_Centroid(lig.geovlak)), 4326)), ST_Y(ST_Transform(ST_Force3D(ST_Centroid(sta.geovlak)), 4326))) as numeric),6) as lat
FROM 
adresseerbaarobjectnevenadresactueel NEV
inner join 
nummeraanduidingactueel NAD
on nev.nevenadres=NAD.identificatie
left outer join   verblijfsobjectactueel VBO
on NEV.identificatie  =VBO.identificatie 
left outer join  standplaatsactueel STA
on NEV.identificatie =  STA.identificatie 
left outer join  ligplaatsactueel LIG
on NEV.identificatie = LIG.identificatie 
WHERE 
(VBO.identificatie is not null or   STA.identificatie is not null or   LIG.identificatie is not null) 
;
--Query returned successfully: 9720223 rows affected, 07:12 minutes execution time.


-- select distinct nummeraanduidingstatus from adresselectie_tot

--En nu alleen de records waarvan de uniq_key niet voorkomt in adres_plus
--en pak van die uniq_key het record dat het meest recent is (obv begindatum NAD, Adresobject)
drop table if exists adresselectie_aanvullend ;
create table adresselectie_aanvullend as
Select A.* from 
(
  Select  row_number() OVER (PARTITION BY h.uniq_key ORDER BY h.nummeraanduidingstatus, h.nad_begin desc ,h.adresseerbaarobject_begin desc) as Rangorde,
  h.*
  from adresselectie_tot H
  left join adres_plus P on H.uniq_key= P.uniq_key
  where p.uniq_key is null)
  a where A.rangorde = 1;
-- Query returned successfully: 278685 rows affected, 32.7 secs execution time.
-- select * from  adresselectie_aanvullend  limit 1000;
-- select count(*) from adresselectie_aanvullend;

-- select distinct adresseerbaarobject_status from adresselectie_aanvullend

-- En haal van deze records de benodigde andere attributen op uit de gerelateerde actueel tabellen en maak een union met de adres_plus records
drop table if exists adres_totaal ;
create table adres_totaal as
SELECT 
  obr.openbareruimtenaam, 
  obr.verkorteopenbareruimtenaam, 
  obr.identificatie AS openbareruimte_id, 
  adr.huisnummer, 
  adr.huisletter, 
  adr.huisnummertoevoeging, 
  adr.postcode, 
  adr.nad_id AS nummeraanduiding_id, 
  wpl.woonplaatsnaam, 
  wpl.identificatie AS woonplaatscode, 
  "PRV".gemeentenaam, 
  "PRV".gemeentecode, 
  "PRV".provincienaam, 
  "PRV".provinciecode, 
  adr.nevenadres, 
  adr.typeadresseerbaarobject, 
  adr.adresseerbaarobject_status, 
  adr.opp_adresseerbaarobject_m2, 
  adr.adresseerbaarobject_id, 
  adr.geopunt, 
  adr.x, 
  adr.y, 
  adr.lon, 
  adr.lat, 
  adr.uniq_key,
  'historisch of toekomstig' as adres_status
FROM 
  adresselectie_aanvullend adr, 
  openbareruimteactueel obr, 
  woonplaatsactueel wpl, 
  provincie_gemeenteactueel "PRV", 
  gemeente_woonplaatsactueelbestaand gemwpl
WHERE 
  adr.obr_id = obr.identificatie AND
  obr.gerelateerdewoonplaats = wpl.identificatie AND
  gemwpl.woonplaatscode = wpl.identificatie AND
  gemwpl.gemeentecode = "PRV".gemeentecode

  union

select 
openbareruimtenaam, 
verkorteopenbareruimtenaam, 
openbareruimte_id, 
huisnummer, 
huisletter, 
huisnummertoevoeging, 
postcode, 
nummeraanduiding_id, 
woonplaatsnaam, 
woonplaatscode, 
gemeentenaam, 
gemeentecode, 
provincienaam, 
provinciecode, 
nevenadres, 
typeadresseerbaarobject, 
adresseerbaarobject_status, 
opp_adresseerbaarobject_m2, 
adresseerbaarobject_id, 
geopunt, 
x, 
y, 
lon, 
lat, 
uniq_key,
 'actueel' as adres_status
from adres_plus;

-- Query returned successfully: 9685652 rows affected, 02:06 minutes execution time.


BEGIN;

-- indexen aanmaken
CREATE INDEX adres_totaal_geom_idx ON adres_totaal USING gist (geopunt); -- Query returned successfully with no result in 01:56 minutes.
CREATE INDEX adres_totaal_postcode ON  adres_totaal USING btree (postcode); -- Query returned successfully with no result in 40.1 secs.
CREATE INDEX adres_totaal_adreseerbaarobject_id ON adres_totaal USING btree (adresseerbaarobject_id);--Query returned successfully with no result in 51.9 secs.
CREATE INDEX adres_totaal_nummeraanduiding_ID ON adres_totaal USING btree (nummeraanduiding_ID);--Query returned successfully with no result in 51.8 secs.
ALTER TABLE adres_totaal ADD PRIMARY KEY (uniq_key);-- Query returned successfully with no result in 57.3 secs.

COMMIT;


-- tijdelijke tabellen verwijderen

drop table if exists adresselectie_tot;
drop table if exists adresselectie_aanvullend ;
