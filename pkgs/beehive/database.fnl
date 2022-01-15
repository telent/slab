(local driver (require :luasql.sqlite3))

(fn get-schema-version [db]
  (let [(cursor err) (db:execute "select version from schema_version")]
    (if (and (not cursor) (string.find err "no such table"))
        ;; empty database
        0
        (cursor:fetch))))

(fn begin-tx [db] (assert (db:execute "begin")))

(fn set-schema-version [db new-version]
  (assert
   (db:execute (.. "update schema_version set version = " new-version)))
  (assert (db:execute "commit")))

(fn migrate-to-newest [db]
  (let [current-version (get-schema-version db)]
    (when (< current-version 1)
      (assert (db:execute "create table schema_version (version integer)"))
      (assert (db:execute "insert into schema_version (version) values (1)")))
    (when (< current-version 2)
      (begin-tx db)
      ;; "The ITU-T E164 recommendations specifies that the maximum no of
      ;; digits for the International geographic, global services,
      ;; Network and Groups of countries applications should be 15."
      ;; 20 is probably excessive future-proofing
      (assert
       (db:execute "
         CREATE TABLE call (
           source_number varchar(20),
           destination_number varchar(20),
           start_at integer, -- epoch time
           end_at integer, -- epoch time
           result_code integer
         )"))
      (set-schema-version db 2))
    (when (< current-version 3)
      (begin-tx db)
      (assert (db:execute "ALTER TABLE call add column duration integer"))
      (assert (db:execute "update call set duration = end_at - start_at"))
      (assert (db:execute "ALTER TABLE call drop column end_at"))
      (set-schema-version db 3))
    ))


(fn new-db []
  (let [db  (: (driver.sqlite3) :connect "beehive-db.sqlite")]
    (migrate-to-newest db)
    db))

(fn replace-params [db command replacements]
  (command:gsub ":([%w_-]+)"
                (fn [word] (db:escape (. replacements word)))))

(fn get-call-history [db end-time limit]
  (let [end-time (or end-time (os.time))
        limit (or limit 10)
        cursor
        (db:execute
         (replace-params db "select source_number, destination_number, start_at, duration, result_code from call where start_at < :end-time order by start_at desc limit :limit"
                         {:end-time end-time :limit limit}))]
    (fn [] (cursor:fetch))))

(fn open []
  {
   :database (new-db)
   :get-call-history (fn [self end-time limit]
                       (get-call-history self.database end-time limit))
;;   :add-call-history add-call-history
   })

(comment
 (local db  (: (driver.sqlite3) :connect "beehive-db.sqlite"))
 )

{ :open open }
