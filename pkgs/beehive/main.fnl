(local database (require :database))
(local db (database:open))

(let [calls (db:get-call-history (os.time) 2)]
  (each [from to time duration res calls]
    (print from time duration)))
