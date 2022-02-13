(local dbus (require :dbus_proxy))
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

(fn request-name [name]
  (let [ret (bus:RequestName name  DBUS_NAME_FLAG_DO_NOT_QUEUE)]
    (match ret
      DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER
      bus

      DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER
      bus

      DBUS_REQUEST_NAME_REPLY_IN_QUEUE
      (values false "unexpected DBUS_REQUEST_NAME_REPLY_IN_QUEUE")

      DBUS_REQUEST_NAME_REPLY_EXISTS
      (values false "already running"))))

{: request-name
 }
