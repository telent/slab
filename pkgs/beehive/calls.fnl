(local lgi (require :lgi))
(local dbus (require :dbus_proxy))
(local GLib lgi.GLib)
(local GV lgi.GLib.Variant)
(local variant dbus.variant)

;; https://www.freedesktop.org/software/ModemManager/api/latest/ref-dbus.html
(local modem-manager
       (dbus.Proxy:new
        {
         :bus dbus.Bus.SYSTEM
         :name "org.freedesktop.ModemManager1"
         :interface "org.freedesktop.DBus.ObjectManager"
         ;; mmcli -L
         :path "/org/freedesktop/ModemManager1"
         }))

;; this is a function because the path to the modem may change
;; (e.g. due to suspend/resume cycles causing services to be stopped
;; and started)

(fn voice []
  (let [modem-path (next (: (assert modem-manager) :GetManagedObjects))]
    (print modem-path)
    (dbus.Proxy:new
     {
      :bus dbus.Bus.SYSTEM
      :name "org.freedesktop.ModemManager1"
      :interface "org.freedesktop.ModemManager1.Modem.Voice"
      :path modem-path
      })))

(fn new-call [number]
  (let [v (GV "s" number)
        _ (print v)
        call-path (: (assert (voice)) :CreateCall {:number v})]
    (dbus.Proxy:new
     ;; https://www.freedesktop.org/software/ModemManager/api/latest/gdbus-org.freedesktop.ModemManager1.Call.html
     {

      :bus dbus.Bus.SYSTEM
      :name "org.freedesktop.ModemManager1"
      :interface "org.freedesktop.ModemManager1.Call"
      :path call-path
      })))


(fn run-events []
  (let [ctx (: (GLib.MainLoop) :get_context)]
    (while (ctx:iteration)
      true)))

(local call-states {
                    :unknown 0
                    :dialing 1
                    :ringing-out 2
                    :ringing-in 3 ; untested
                    :active 4
                    :terminated 7
                    })

(fn make-call [number]
  (let [call (new-call number)]
    (var terminated false)
    (call:connect_signal
     (fn [p old new reason]
       (print "state changed " old new (type new) reason)
       (when (= new call-states.active)
         (print "connected")
         (os.execute "route-audio phone"))
       (when (= new call-states.terminated)
         (print "hangup")
         (os.execute "route-audio reset")
         (set terminated true)))
     "StateChanged")
    (call:connect_signal
     (fn [p old new reason] (print "properties changed " old new reason))
     "PropertiesChanged")
    (call:Start)))

{ :voice voice :make-call make-call :modem-mananger modem-manager}
