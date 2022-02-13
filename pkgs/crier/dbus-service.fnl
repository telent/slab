(local { : Gio : GLib &as lgi } (require :lgi))
(local dbus (require :dbus_proxy))
(local GV lgi.GLib.Variant)

(local inspect (require :inspect))

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

(fn interface-info [xml]
  (let [node-info (Gio.DBusNodeInfo.new_for_xml xml)]
    (. node-info.interfaces 1)))

(fn args-signature [args]
  (var sig "")
  (each [_ v (ipairs args)]
    (set sig (.. sig v.signature)))
  sig)

(fn handle-dbus-method-call [self conn sender path interface method params invocation]
  (when (and (= path self.attrs.path)
             (= interface self.attrs.interface))
    (let [p (dbus.variant.strip params)
          info (self.interfaces:lookup_method method)
          sig (args-signature info.out_args)]
      (match (table.pack (pcall (. self.methods method) (table.unpack p)))
        [true & vals]
        (invocation:return_value (GV (.. "(" sig ")") vals))
        _
        (invocation:return_value nil)))))

(fn register-object [self xml methods]
  (let [interfaces (interface-info xml)]
    (tset self :methods methods)
    (tset self :interfaces interfaces)
    (Gio.DBusConnection.register_object
     bus.connection
     self.attrs.path
     interfaces
     (lgi.GObject.Closure #(handle-dbus-method-call self $...))
     (lgi.GObject.Closure #(error "no properties to get"))
     (lgi.GObject.Closure #(error "no properties to set")))))

(fn new [{: name &as attrs}]
  (match (request-name name)
    (false errmsg) (error errmsg)
    bus
    {
     : attrs
     :register-object register-object
     :emit-signal (fn [self name sig params]
                    (bus.connection:emit_signal
                     nil ; destination
                     attrs.path
                     attrs.interface
                     name
                     (GV sig params)))
     }))

{: new }
