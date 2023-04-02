DROP INDEX IF EXISTS mimiciv_hosp.labevents_idx02;
CREATE INDEX labevents_idx02
  ON mimiciv_hosp.labevents (specimen_id);
  
DROP INDEX IF EXISTS mimiciv_hosp.labevents_idx03;
CREATE INDEX labevents_idx03
  ON mimiciv_hosp.labevents (itemid);
  
DROP INDEX IF EXISTS mimiciv_hosp.d_labitems_idx01;
CREATE INDEX d_labitems_idx01
  ON mimiciv_hosp.d_labitems (itemid);
  
DROP INDEX IF EXISTS mimiciv_hosp.pharmacy_idx01;
CREATE INDEX pharmacy_idx01
  ON mimiciv_hosp.pharmacy (pharmacy_id);
  
  
DROP INDEX IF EXISTS mimiciv_hosp.prescriptions_idx01;
CREATE INDEX prescriptions_idx01
  ON mimiciv_hosp.prescriptions (pharmacy_id);
  
  
DROP INDEX IF EXISTS mimiciv_hosp.emar_idx01;
CREATE INDEX emar_idx01
  ON mimiciv_hosp.emar (pharmacy_id);
  
DROP INDEX IF EXISTS mimiciv_hosp.emar_idx02;
CREATE INDEX emar_idx02
  ON mimiciv_hosp.emar (poe_id);
  
DROP INDEX IF EXISTS mimiciv_hosp.poe_idx01;
CREATE INDEX poe_idx01
  ON mimiciv_hosp.poe (poe_id);
