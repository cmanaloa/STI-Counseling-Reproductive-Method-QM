-- Patients 13-24 with medical visit in measurement period
DROP TABLE IF EXISTS universe;
CREATE TEMPORARY TABLE universe AS
SELECT patients.id    AS patient_id,
       patients.primary_care_giver_id,
       patients.primary_location_id
FROM patients
WHERE EXTRACT(YEAR FROM AGE({{measurement_period_start_date}}, patients.date_of_birth)) >= 13 AND
  EXTRACT(YEAR FROM AGE({{measurement_period_start_date}}, patients.date_of_birth)) < 24
  AND EXISTS(
        SELECT
        FROM visits
                 INNER JOIN visit_set_memberships ON visit_set_memberships.visit_id = visits.id
        WHERE visits.patient_id = patients.id
          AND visit_set_memberships.standard_visit_set_id = 'uds_medical'
          AND visits.visit_date :: DATE BETWEEN {{measurement_period_start_date}} AND {{measurement_period_end_date}}
    );
CREATE INDEX index_universe_on_patient_id ON universe (patient_id);

-- Birth Control codes, last 12 months
DROP TABLE IF EXISTS temp_last_bc;
CREATE TEMP TABLE temp_last_bc AS
SELECT DISTINCT ON (patient_id) v.patient_id,
                                v.visit_date :: DATE AS performed_on
FROM visit_diagnosis_codes vdc
                  INNER JOIN diagnosis_codes dc ON dc.id = vdc.diagnosis_code_id
                  INNER JOIN visits v ON v.id = vdc.visit_id
         WHERE code IN (
                        'Z30',
                        'Z30.0',
                        'Z30.01', 
                        'Z30.011',
                        'Z30.012',
                        'Z30.013',
                        'Z30.014',
                        'Z30.015', 
                        'Z30.016', 
                        'Z30.017', 
                        'Z30.018', 
                        'Z30.019',
                        'Z30.02',
                        'Z30.09',
                        'Z30.2', 
                        'Z30.4', 
                        'Z30.40', 
                        'Z30.41',
                        'Z30.42',
                        'Z30.43',
                        'Z30.430', 
                        'Z30.431',
                        'Z30.432',
                        'Z30.433',
                        'Z30.44',
                        'Z30.45', 
                        'Z30.46',
                        'Z30.49', 
                        'Z30.8',
                        'Z30.9'
             )
           AND v.visit_date :: DATE BETWEEN {{measurement_period_start_date}} AND {{measurement_period_end_date}}
ORDER BY patient_id,
         performed_on DESC
;
CREATE INDEX index_temp_last_bc_on_patient_id ON temp_last_bc (patient_id);

SELECT universe.patient_id                                      AS patient_id,
       universe.primary_care_giver_id                           AS provider_id,
       universe.primary_location_id                             AS location_id,
       'Last BC screen: '  || COALESCE(TO_CHAR(bc.performed_on, 'MM/DD/YYYY'), 'None') AS measurement_value,
       CASE
           WHEN bc.patient_id IS NOT NULL THEN TRUE
           ELSE FALSE END                                       AS numerator,
       FALSE                                                    AS exclusion
FROM universe
         LEFT JOIN temp_last_bc bc ON bc.patient_id = universe.patient_id