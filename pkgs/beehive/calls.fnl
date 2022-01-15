(local lgi (require :lgi))
(local dbus (require :dbus_proxy))

(local gtk lgi.Gtk)

(let [window (gtk.Window {
                          :title "My window"
                          :default_width 400
                          :default_height 400
                          })]
  (window:show_all))


(local osk (dbus.Proxy:new
            {
             :bus dbus.Bus.SESSION
             :name "sm.puri.OSK0"
             :interface "sm.puri.OSK0"
             :path "/sm/puri/OSK0"
             }))

(comment
 (gtk:main)
 (local osk m.proxy)
 (osk:SetVisible true)
 (osk:SetVisible false))

{ : osk }
