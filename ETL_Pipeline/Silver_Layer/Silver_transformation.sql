
-- =====================================================
-- PROJECT: AIRLINE FLIGHT OPERATIONS ANALYTICS
-- LAYER: SILVER
-- PURPOSE: DATA CLEANING AND VALIDATION
-- =====================================================

-- STEP 1: CLEAN VALID FLIGHTS

CREATE OR REFRESH MATERIALIZED VIEW silver_flights_clean AS

WITH ranked_flights AS (

    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY flight_id
            ORDER BY loaded_at, source_file
        ) AS rn

    FROM bronze_airline_flights
),

cleaned AS (

    SELECT
        flight_id,
        flight_number,

        COALESCE(NULLIF(INITCAP(TRIM(airline)), ''), 'Unknown')
            AS airline,

        COALESCE(NULLIF(TRIM(aircraft_id), ''), 'Unknown')
            AS aircraft_id,

        INITCAP(TRIM(aircraft_type)) AS aircraft_type,

        flight_date,
        day_of_week,

        INITCAP(TRIM(origin_city)) AS origin_city,
        INITCAP(TRIM(destination_city)) AS destination_city,

        INITCAP(TRIM(origin_region)) AS origin_region,

        distance_km,
        scheduled_departure,
        actual_departure,

        COALESCE(
            delay_minutes,
            TIMESTAMPDIFF(
                MINUTE,
                scheduled_departure,
                actual_departure
            )
        ) AS delay_minutes,

        COALESCE(
            NULLIF(INITCAP(TRIM(delay_reason)), ''),
            'Unknown'
        ) AS delay_reason,

        seat_capacity,
        passengers,
        avg_fare,

        COALESCE(
            ticket_revenue,
            passengers * avg_fare
        ) AS ticket_revenue,

        fuel_cost,
        source_file,
        loaded_at

    FROM ranked_flights
    WHERE rn = 1
)

SELECT *,
    CASE
        WHEN delay_minutes <= 15 THEN 'On Time'
        WHEN delay_minutes <= 60 THEN 'Minor Delay'
        ELSE 'Major Delay'
    END AS delay_category

FROM cleaned

WHERE passengers BETWEEN 0 AND seat_capacity
  AND avg_fare >= 0;


-- STEP 2: STORE REJECTED FLIGHTS

CREATE OR REFRESH MATERIALIZED VIEW silver_flights_rejected AS

WITH ranked_flights AS (

    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY flight_id
            ORDER BY loaded_at, source_file
        ) AS rn

    FROM bronze_airline_flights
)

SELECT *,

    CASE
        WHEN passengers > seat_capacity
            THEN 'Passengers more than seat capacity'

        WHEN passengers < 0
            THEN 'Negative passenger count'

        WHEN avg_fare < 0
            THEN 'Negative average fare'

    END AS reject_reason

FROM ranked_flights

WHERE rn = 1
  AND (
      passengers > seat_capacity
      OR passengers < 0
      OR avg_fare < 0
  );
