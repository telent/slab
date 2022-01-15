(local lgi (require :lgi))
(local Gtk lgi.Gtk)
(local Pango lgi.Pango)
(local database (require :database))

(local db (database.open))

(fn recent [number entry]
  (doto (Gtk.Button {:on_clicked (fn [self blah]
                                   (entry:set_text number)
                                   (print "clicked"))})
    (: :add
       (Gtk.Label { :label number }))))

(let [entry (Gtk.Entry {
                        :attributes (doto (Pango.AttrList {})
                                      (: :insert (Pango.attr_size_new 20_000)))
                        })
      vbox (Gtk.VBox { :spacing 4 })
      hbox (Gtk.HBox {})
      window (Gtk.Window {
                          :title "Dialler"
                          :default_width 400
                          :default_height 400
                          })]
  (hbox:pack_start (Gtk.Label { :label "Number" }) false true 6)
  (hbox:pack_start entry true true 6)
  (hbox:pack_end
   (doto (Gtk.Button {:on_clicked (fn [self blah]
                                    (print "calling ..."))})
     (: :set_image
        (Gtk.Image.new_from_icon_name "call-start"  Gtk.IconSize.DIALOG)))
   false true 4)

  (vbox:pack_start hbox true true 10)
  (vbox:pack_start (Gtk.Label { :label "Recent calls" }) true true 10)
  (each [call (db:get-call-history)]
    (vbox:pack_start
     (recent call.destination_number entry)
     true true 6))

  (window:add vbox)
  (window:show_all))


(Gtk:main)
