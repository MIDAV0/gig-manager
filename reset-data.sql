DELETE FROM ACT;
DELETE FROM VENUE;
DELETE FROM ACT_GIG;
DELETE FROM GIG;
DELETE FROM TICKET;
DELETE FROM GIG_TICKET;

ALTER SEQUENCE act_actid_seq RESTART WITH 10001;
ALTER SEQUENCE venue_venueid_seq RESTART WITH 10001;
ALTER SEQUENCE gig_gigid_seq RESTART WITH 10001;
ALTER SEQUENCE act_actid_seq RESTART WITH 10001;
ALTER SEQUENCE ticket_ticketid_seq RESTART WITH 10001;

