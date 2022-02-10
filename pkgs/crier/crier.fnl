(local lgi (require :lgi))
(local dbus (require :dbus_proxy))
(local Gio lgi.Gio)
(local GLib lgi.GLib)
(local GV lgi.GLib.Variant)
(local variant dbus.variant)
(local inspect (require :inspect))
(local Gtk lgi.Gtk)


(local dbus-service-attrs
       {
        :bus dbus.Bus.SESSION
        :name "org.freedesktop.Notifications"
        :interface "org.freedesktop.Notifications"
        :path "/org/freedesktop/Notifications"
        })

(local bus (dbus.Proxy:new
            {
             :bus dbus.Bus.SESSION
             :name "org.freedesktop.DBus"
             :interface "org.freedesktop.DBus"
             :path "/org/freedesktop/DBus"
             }))


(local DBUS_NAME_FLAG_DO_NOT_QUEUE 4)
(local DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER 1)
(local DBUS_REQUEST_NAME_REPLY_IN_QUEUE 2)
(local DBUS_REQUEST_NAME_REPLY_EXISTS 3)
(local DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER 4)


(let [ret (bus:RequestName dbus-service-attrs.name
                           DBUS_NAME_FLAG_DO_NOT_QUEUE)]
  (match ret
    DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER
    true

    DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER
    true

    DBUS_REQUEST_NAME_REPLY_IN_QUEUE
    (error "unexpected DBUS_REQUEST_NAME_REPLY_IN_QUEUE")

    DBUS_REQUEST_NAME_REPLY_EXISTS
    (error "already running")))

(var notification-id 10)
(fn next-id []
  (set notification-id  (+ notification-id  1))
  notification-id)


(fn handle-dbus-method-call [conn sender path interface method params invocation]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface))
    (match method
      "GetCapabilities"
      (invocation:return_value (GV "as" ["actions"]))

      "GetServerInformation"
      (invocation:return_value
       (GV "(ssss)" ["crier"
                     "telent"
                     "0.1"
                     "1.2"]))

      "Notify"
      (let [p params]
        (print (inspect (dbus.variant.strip p)))
        (invocation:return_value (GV "(u)" [(next-id)]))))))

(fn handle-dbus-get [conn sender path interface name]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface)
             (= name "Visible"))
    (lgi.GLib.Variant "b" true)))

(local interface-info
       (let [xml (: (io.open "interface.xml" "r") :read "*a")
             node-info (Gio.DBusNodeInfo.new_for_xml xml)]
         (. node-info.interfaces 1)))

(Gio.DBusConnection.register_object
 bus.connection
 dbus-service-attrs.path
 interface-info
 (lgi.GObject.Closure handle-dbus-method-call)
 (lgi.GObject.Closure handle-dbus-get)
 (lgi.GObject.Closure (fn [a] (print "set"))))

(Gtk:main)
