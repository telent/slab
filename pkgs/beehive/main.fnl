(local lgi (require :lgi))
(local gtk lgi.Gtk)
(local calls (require :calls))

(fn window []
  (let [window (gtk.Window {
                            :title "My window"
                            :default_width 400
                            :default_height 400
                            })]
    (window:show_all)))

(print "calling " (os.getenv "PHONE"))
(calls:make-call (os.getenv "PHONE") false)

(window)
(gtk:main)
