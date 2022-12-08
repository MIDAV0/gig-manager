/*Put your CREATE TABLE statements (and any other schema related definitions) here*/

DROP TABLE IF EXISTS act CASCADE;
DROP TABLE IF EXISTS venue CASCADE;
DROP TABLE IF EXISTS act_gig CASCADE;
DROP TABLE IF EXISTS gig CASCADE;
DROP TABLE IF EXISTS ticket CASCADE;
DROP TABLE IF EXISTS gig_ticket CASCADE;
DROP FUNCTION IF EXISTS checkAllConditions CASCADE;
DROP FUNCTION IF EXISTS checkTicketConditions CASCADE;
DROP FUNCTION IF EXISTS checkGigConditions CASCADE;
DROP TABLE IF EXISTS newacts CASCADE;



CREATE TABLE act(
    actID SERIAL PRIMARY KEY,
    actname VARCHAR(100) NOT NULL UNIQUE,
    genre VARCHAR(10) NOT NULL,
    standardfee INTEGER NOT NULL CHECK (standardfee >= 0)
);

CREATE TABLE venue(
    venueid SERIAL PRIMARY KEY,
    venuename VARCHAR(100) NOT NULL UNIQUE,
    hirecost INTEGER NOT NULL CHECK (hirecost >= 0),
    capacity INTEGER NOT NULL CHECK (capacity >= 0)
);

CREATE TABLE gig(
    gigID SERIAL PRIMARY KEY,
    venueid INTEGER REFERENCES venue(venueid),
    gigtitle VARCHAR(100) NOT NULL,
    gigdate TIMESTAMP NOT NULL,
    gigstatus VARCHAR(10) NOT NULL CHECK (gigstatus IN ('Cancelled', 'GoingAhead'))
);

CREATE TABLE act_gig (
    actID INTEGER REFERENCES act(actID),
    gigID INTEGER REFERENCES gig(gigID),
    actfee INTEGER NOT NULL CHECK (actfee >= 0),
    ontime TIMESTAMP NOT NULL,
    duration INTEGER NOT NULL CHECK (duration > 0 AND ontime + duration * interval '1 minute' < ontime::date + interval '1 day'),
    PRIMARY KEY(actID, gigID, ontime)
);

CREATE TABLE gig_ticket(
    gigID INTEGER REFERENCES gig(gigID),
    pricetype VARCHAR(2) NOT NULL,
    price INTEGER NOT NULL CHECK (price >= 0),
    PRIMARY KEY (gigID, pricetype)
);

CREATE TABLE ticket(
    ticketID SERIAL PRIMARY KEY,
    gigID INTEGER REFERENCES gig(gigID),
    pricetype VARCHAR(2) NOT NULL,
    Cost INTEGER NOT NULL CHECK (Cost >= 0),
    CustomerName VARCHAR(100) NOT NULL,
    CustomerEmail VARCHAR(100) NOT NULL
);


-- Option 2

CREATE TABLE newacts(
    actID INTEGER NOT NULL REFERENCES act(actID),
    ontime TIMESTAMP NOT NULL,
    duration INTEGER NOT NULL CHECK (duration > 0 AND ontime + duration * interval '1 minute' < ontime::date + interval '1 day'),
    actfee INTEGER NOT NULL CHECK (actfee >= 0),
    PRIMARY KEY(actID, ontime)
);


CREATE OR REPLACE FUNCTION checkAllConditions(venue_name VARCHAR, ticket_price INTEGER, gig_date TIMESTAMP, gig_title VARCHAR) RETURNS BOOLEAN Language plpgsql AS $$
DECLARE
    CheckActAfterGig BOOLEAN;
    CheckActsAtGigOverlap BOOLEAN;
    CheckActAtMultipleGigs BOOLEAN;
    CheckActTravelToVenue BOOLEAN;
    CheckVenueOverlap BOOLEAN;
    CheckVenueThreeHourGap BOOLEAN;
    CheckGigLineUp BOOLEAN;
    CheckSameDayGig BOOLEAN;
    venue_ID INTEGER;
    actrecord RECORD;
    newGigID INTEGER;
BEGIN
    SELECT venueid INTO venue_ID FROM venue WHERE venuename = venue_name;

    INSERT INTO gig(venueid, gigtitle, gigdate, gigstatus) VALUES (venue_ID, gig_title, gig_date, 'GoingAhead') RETURNING gigid INTO newGigID;
    INSERT INTO gig_ticket(gigid, pricetype, price) VALUES (newGigID, 'A', ticket_price);

    FOR actrecord IN (SELECT * FROM newacts ORDER BY ontime)
    LOOP
        SELECT gig.gigdate <= actrecord.ontime INTO CheckActAfterGig FROM gig WHERE gig.gigid = newGigID;
        SELECT COUNT(*) = 0 INTO CheckActsAtGigOverlap FROM act_gig WHERE gigID = newGigID AND (ontime, duration * INTERVAL '1 minute') OVERLAPS (actrecord.ontime, actrecord.duration * INTERVAL '1 minute');
        SELECT COUNT(*) = 0 INTO CheckActAtMultipleGigs FROM act_gig WHERE actID = actrecord.actid AND (ontime, duration * INTERVAL '1 minute') OVERLAPS (actrecord.ontime, actrecord.duration * INTERVAL '1 minute');
        SELECT COUNT(*) = 0 INTO CheckActTravelToVenue FROM act_gig JOIN gig ON act_gig.gigid = gig.gigid WHERE act_gig.actID = actrecord.actid AND gig.venueID != venue_ID AND (actrecord.ontime::timestamp - INTERVAL '20 minutes', (actrecord.duration + 20) * INTERVAL '1 minute') OVERLAPS (act_gig.ontime, act_gig.duration * INTERVAL '1 minute');
        SELECT COUNT(*) = 0 INTO CheckVenueOverlap FROM act_gig WHERE gigid IN (SELECT gigid FROM gig WHERE venueid = venue_ID) AND (ontime, duration * INTERVAL '1 minute') OVERLAPS (actrecord.ontime, actrecord.duration * INTERVAL '1 minute');
        SELECT COUNT(*) = 0 INTO CheckVenueThreeHourGap FROM act_gig WHERE gigid in (SELECT gigid FROM gig WHERE venueid = venue_ID) AND gigid != newGigID AND (ontime, duration * INTERVAL '1 minute') OVERLAPS (actrecord.ontime::timestamp - INTERVAL '3 hours', actrecord.duration * INTERVAL '1 minute' + INTERVAL '3 hours');
        SELECT ((actrecord.ontime - MAX(ontime + duration * INTERVAL '1 minute')) <= INTERVAL '20 minutes' OR COUNT(*) = 0) INTO CheckGigLineUp FROM act_gig WHERE gigid = newGigID;
        SELECT (actrecord.ontime::date + INTERVAL '1 day' > actrecord.ontime + actrecord.duration * INTERVAL '1 minute') INTO CheckSameDayGig;

        IF CheckActAfterGig AND CheckActsAtGigOverlap AND CheckActAtMultipleGigs AND CheckActTravelToVenue AND CheckVenueOverlap AND CheckVenueThreeHourGap AND CheckGigLineUp AND CheckSameDayGig THEN
            INSERT INTO act_gig (actid, gigid, actfee, ontime, duration) VALUES (actrecord.actid, newGigID, actrecord.actfee, actrecord.ontime, actrecord.duration);
        ELSE
            DELETE FROM newacts;
            DELETE FROM act_gig WHERE gigid = newGigID;
            DELETE FROM gig_ticket WHERE gigid = newGigID;
            DELETE FROM gig WHERE gigid = newGigID;
            RETURN FALSE;
        END IF;

    END LOOP;
    RETURN TRUE;
END;
$$;


-- Option 3

CREATE OR REPLACE FUNCTION checkTicketConditions(gig_ID INTEGER, ticket_type VARCHAR(2), customer_name VARCHAR(100), customer_email VARCHAR(100)) RETURNS BOOLEAN Language plpgsql AS $$
DECLARE
    CheckGigStatus BOOLEAN;
    CheckVenueCapacity BOOLEAN;
    CheckTicketPrice BOOLEAN;
    ticketPrice INTEGER;
BEGIN
    SELECT EXISTS(SELECT * FROM gig WHERE gigid = gig_ID AND gigstatus = 'GoingAhead') INTO CheckGigStatus;
    SELECT (COUNT(*) = (SELECT venue.capacity FROM venue, gig WHERE gig.gigid = gig_ID AND venue.venueid = gig.venueid)) INTO CheckVenueCapacity FROM ticket WHERE ticket.gigid = gig_ID;
    SELECT EXISTS(SELECT * FROM gig_ticket WHERE gigid = gig_ID AND pricetype = ticket_type) INTO CheckTicketPrice;

    IF CheckGigStatus AND NOT CheckVenueCapacity AND CheckTicketPrice THEN
        SELECT price INTO ticketPrice FROM gig_ticket WHERE gigid = gig_ID AND pricetype = ticket_type;
        INSERT INTO ticket (gigid, pricetype, cost, customername, customeremail) VALUES (gig_ID, ticket_type, ticketPrice, customer_name, customer_email);
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$;


-- Option 5
CREATE VIEW tickets_to_sell AS 
SELECT gig.gigid, (venue.hirecost + (SELECT SUM(act_gig.actfee) FROM act_gig WHERE act_gig.gigid = gig.gigid)) / (SELECT gig_ticket.price FROM gig_ticket WHERE gig_ticket.gigid = gig.gigid AND gig_ticket.pricetype = 'A') - (SELECT COUNT(*) FROM ticket WHERE ticket.gigid = gig.gigid) AS tts
FROM venue, gig 
WHERE venue.venueid = gig.venueid;


-- Option 6
CREATE VIEW headliner AS SELECT gigid, MAX(ontime) AS maxtime FROM act_gig WHERE (SELECT gig.gigstatus = 'GoingAhead' FROM gig WHERE gig.gigid = act_gig.gigid) = TRUE GROUP BY gigid;
CREATE VIEW valid_act_gig AS SELECT act_gig.actid, act_gig.gigid, act_gig.ontime FROM act_gig, headliner WHERE act_gig.gigid = headliner.gigid AND act_gig.ontime = headliner.maxtime;
CREATE VIEW ticket_count AS SELECT (SELECT actname FROM act WHERE act.actid = valid_act_gig.actid) AS actName, DATE_PART('year', valid_act_gig.ontime)::text AS actYear, COUNT(ticketID) AS tcount FROM ticket JOIN valid_act_gig ON ticket.gigid = valid_act_gig.gigid GROUP BY actname, actYear ORDER BY COUNT(ticketID) ASC;
CREATE VIEW ticket_count_total AS SELECT (SELECT actname FROM act WHERE act.actid = valid_act_gig.actid) AS actName, 'Total' AS actYear, COUNT(ticketID) AS tcount FROM ticket JOIN valid_act_gig ON ticket.gigid = valid_act_gig.gigid GROUP BY actname ORDER BY COUNT(ticketID) ASC;
CREATE VIEW combined_tickets AS SELECT actName, actYear, tcount FROM ticket_count UNION SELECT actName, actYear, tcount FROM ticket_count_total;


-- Option 7
CREATE VIEW customer_list AS SELECT (SELECT actname FROM act WHERE act.actid = valid_act_gig.actid) AS actName, DATE_PART('year', valid_act_gig.ontime)::text AS actYear, customerName, COUNT(*) as ticketsBought FROM ticket, valid_act_gig WHERE ticket.gigid = valid_act_gig.gigid GROUP BY customerName, actName, actYear ORDER BY actName ASC;
CREATE VIEW all_years AS SELECT (SELECT actname FROM act WHERE act.actid = valid_act_gig.actid) AS actName, COUNT(DISTINCT DATE_PART('year', valid_act_gig.ontime)::text) AS actCount FROM valid_act_gig GROUP BY actName;
CREATE VIEW all_customer_years AS SELECT actName, customerName, COUNT(DISTINCT actYear), COUNT(ticketsBought) AS customerCount FROM customer_list GROUP BY customerName, actName;
CREATE VIEW combined_years AS SELECT all_years.actName AS actN, all_customer_years.customerName AS custN, all_customer_years.customerCount AS tCount FROM all_years, all_customer_years WHERE all_years.actName = all_customer_years.actName AND all_years.actCount = all_customer_years.customerCount;
CREATE VIEW noneAct AS SELECT (SELECT actname FROM act WHERE act.actid = valid_act_gig.actid) AS actN, '[None]' AS custN, 0 AS tCount FROM valid_act_gig WHERE NOT EXISTS (SELECT * FROM ticket WHERE ticket.gigid = valid_act_gig.gigid);
CREATE VIEW regularCustomers AS SELECT actN, custN, tCount FROM combined_years UNION SELECT actN, custN, tCount FROM noneAct;


-- Option 8
CREATE VIEW avgTicketPrice AS SELECT SUM(ticket.cost)/COUNT(*) AS avgPrice FROM ticket, gig WHERE ticket.gigid = gig.gigid AND gig.gigstatus = 'GoingAhead';
CREATE VIEW feasible_act AS SELECT venue.venueName AS vName, act.actName AS aName, ((venue.hirecost + act.standardfee) / avgTicketPrice.avgPrice) AS ticketC FROM venue, act, avgTicketPrice WHERE venue.capacity >= (venue.hirecost + act.standardfee) / avgTicketPrice.avgPrice;


-- Option 4
CREATE OR REPLACE FUNCTION checkGigConditions(gig_ID INTEGER, act_name VARCHAR) RETURNS TABLE (customerEmail VARCHAR) Language plpgsql AS $$
DECLARE
    act_ID INTEGER;
    CheckActExists BOOLEAN;
    CheckGigHeadline BOOLEAN;
    CheckFirstAct BOOLEAN;
    el RECORD;
    CheckActBetweenActs BOOLEAN;
    CheckBetween BOOLEAN;
BEGIN
    SELECT actid INTO act_ID FROM act WHERE actname = act_name;
    SELECT EXISTS(SELECT * FROM act_gig WHERE gigid = gig_ID AND actid = act_ID) INTO CheckActExists;

    IF NOT CheckActExists THEN
        RETURN;
    END IF;

    SELECT gig_ID IN (SELECT gigid FROM valid_act_gig) INTO CheckGigHeadline;
    SELECT act_gig.ontime = gig.gigdate INTO CheckFirstAct FROM act_gig, gig WHERE act_gig.gigid = gig_ID AND act_gig.actid = act_ID AND act_gig.gigid = gig.gigid;

    CheckBetween := TRUE;
    FOR el IN(SELECT ontime, duration FROM act_gig WHERE gigid = gig_ID AND actid = act_ID)
    LOOP
        SELECT COUNT(*) = 2 INTO CheckActBetweenActs FROM act_gig WHERE gigid = gig_ID AND (ontime, duration * INTERVAL '1 minute') OVERLAPS (el.ontime::timestamp - INTERVAL '1 minute', el.duration * INTERVAL '1 minute' + INTERVAL '1 minute');
        IF NOT CheckActBetweenActs THEN
            CheckBetween := FALSE;
        END IF;
    END LOOP;

    IF CheckGigHeadline OR CheckFirstAct OR NOT CheckBetween THEN
        UPDATE ticket SET cost = 0 WHERE gigid = gig_ID;
        UPDATE gig SET gigstatus = 'Cancelled' WHERE gigid = gig_ID;
        DELETE FROM act_gig WHERE gigid = gig_ID;
        RETURN QUERY SELECT DISTINCT ticket.customeremail FROM ticket WHERE gigid = gig_ID ORDER BY ticket.customeremail ASC;
    ELSE
        DELETE FROM act_gig WHERE gigid = gig_ID AND actid = act_ID;
        RETURN;
    END IF;
END;
$$;
